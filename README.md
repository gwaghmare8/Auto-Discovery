# Building a Highly Available, Scalable and Secure Architecture for a Pet Adoption Clinic on AWS

## Part 1: Introduction and Problem Statement

A pet adoption clinic wants to move its application online. Families browse pets, book visits and submit adoption applications, so the platform stores personal data: names, addresses, phone numbers and household details. The client set three requirements:

- **High availability.** The application must stay up when a server or an entire data centre fails. Families should never find the site down while they are trying to adopt.
- **High scalability.** Traffic spikes around campaigns and adoption events. The platform must grow during peaks and shrink afterwards, so the client pays only for what it uses.
- **High security.** Users' privacy is the top priority. Data must be encrypted, private resources must not be reachable from the internet, and no secret may be stored in code.

This article describes how we met these requirements on AWS with Terraform for the infrastructure, Jenkins for the CI/CD pipeline and Ansible for deployments. The whole environment is created from code, so it is repeatable and reviewable.


Architecture diagram

<img width="1689" height="1478" alt="image" src="https://github.com/user-attachments/assets/62f8efbc-e565-4d46-8f0d-234e69775af5" />

## Part 2: Resources and Their Uses

### Networking
| Resource | Purpose |
|---|---|
| **VPC (10.0.0.0/16)** | An isolated private network for the whole application. |
| **2 public and 2 private subnets across 2 Availability Zones** | Public subnets hold only internet-facing components. Private subnets hold the application servers, the build and deploy tooling and the database. Using two AZs removes a single point of failure. |
| **Internet Gateway and NAT Gateway** | The Internet Gateway serves the public subnets. The NAT Gateway lets private servers reach the internet for updates and packages, with no inbound path from the internet. |
| **Security groups** | Each tier accepts traffic only from the tier in front of it. Examples: the app servers accept port 8080 only from the load balancer, and the database accepts port 3306 only from the app servers. |

### Application tier (Staging and Production)
| Resource | Purpose |
|---|---|
| **Application Load Balancer (ALB)** | The public entry point. It terminates HTTPS and spreads requests across healthy servers. |
| **Auto Scaling Group (ASG)** | Runs 1 to 3 servers across both AZs, replaces unhealthy ones and adds servers when average CPU passes 70%. This provides availability and scalability. |
| **Launch Template** | Defines the server: RHEL 9, Docker, the New Relic agent and the script that pulls the latest application image from Nexus. |
| **Docker container** | Packages the pet adoption application (listening on port 8080) so every server runs the same build. |
| **Separate staging and production environments** | Releases are tested in staging before they reach production. |

### Data tier
| Resource | Purpose |
|---|---|
| **Amazon RDS for MySQL** | Stores application data. It sits in private subnets, is not publicly accessible, uses encrypted storage and accepts connections only from the application and bastion security groups. |
| **HashiCorp Vault** | Holds the database credentials. Terraform reads them at deploy time, so no password appears in code. |

### CI/CD and tooling
| Resource | Purpose |
|---|---|
| **Jenkins** | Runs the pipeline: secret scan with Gitleaks, infrastructure scan with Checkov, then Terraform init, validate, plan and apply. It sends results to Slack. |
| **SonarQube** | Static code analysis (SAST) to catch bugs and vulnerabilities before release. |
| **Nexus** | The private Docker registry and artifact repository that stores application images. |
| **Ansible server** | A control node in a private subnet. It finds the servers in each Auto Scaling Group and makes sure they run the latest container. |
| **Bastion host** | The controlled way into the private network. It has no inbound ports open and is reached through AWS Systems Manager Session Manager. |

### Security and operations
| Resource | Purpose |
|---|---|
| **AWS Certificate Manager (ACM) and Route 53** | Issue the HTTPS certificates and provide friendly names (`prod.`, `stage.`, `nexus.`, `sonarqube.`, `jenkins.`, `vault.`). |
| **AWS KMS** | Auto-unseals Vault and encrypts data at rest. |
| **SSM Parameter Store and Secrets Manager** | Store the New Relic key, the tool admin passwords and the Vault bootstrap output, so no secret lives in the repository. |
| **IAM roles with least privilege** | Each server gets only the permissions it needs. Jenkins logs in to Vault with its IAM role, with no stored token. |
| **IMDSv2 and encrypted EBS volumes** | Protect instance credentials and data on disk. |
| **S3 backend with DynamoDB locking** | Stores Terraform state with versioning, encryption and locking, so two people cannot change the infrastructure at once. |
| **New Relic** | Monitors every server for performance and health. |

## Part 3: Flow of the Architecture

### 1. How a user reaches the application
1. A visitor opens `prod.<domain>`. **Route 53** resolves the name to the **Application Load Balancer**.
2. The ALB terminates **HTTPS** using the ACM certificate, so traffic from the browser is encrypted.
3. The ALB forwards the request on port 8080 to a healthy server in the **Auto Scaling Group** in a private subnet. The servers have no public IP.
4. The container reads and writes data in **RDS**, in a separate private subnet. Only the application servers can reach it.
5. If a server fails or load rises, the ASG replaces or adds servers across both AZs, and the ALB sends traffic only to healthy ones.

### 2. How the infrastructure is deployed and updated
1. An engineer pushes a change to the repository. **Jenkins** detects it and starts the pipeline.
2. **Gitleaks** checks for committed secrets and **Checkov** scans the Terraform code for misconfigurations.
3. Terraform runs `init`, `fmt`, `validate` and `plan`, then `apply` (or `destroy`) with the chosen action. State is stored in the S3 backend and locked in DynamoDB.
4. The result is posted to **Slack**.
5. Once running, the **Ansible server** checks the staging and production Auto Scaling Groups every minute, finds the servers' private IPs and makes sure each runs the latest application image from **Nexus**.

### 3. How secrets and administrators are handled
- The database password is generated inside **Vault**. Jenkins authenticates with its **IAM role**, and Terraform reads the password only when it creates the database.
- Administrators connect through **Session Manager** and the **bastion host**. No SSH port is exposed to the internet.
- **New Relic** reports from every host, using a key fetched from **Parameter Store** at boot.

### Outcome
| Requirement | How it is met |
|---|---|
| **High availability** | Two Availability Zones, a load balancer with health checks and Auto Scaling replacing failed servers. |
| **High scalability** | CPU-based scaling from 1 to 3 servers per environment, with room to raise the limits. |
| **High security** | Private subnets, tier-to-tier security groups, HTTPS everywhere, encryption at rest, Vault-managed credentials, least-privilege IAM and secret scanning in the pipeline. |
