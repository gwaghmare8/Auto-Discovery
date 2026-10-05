pipeline {
    agent any
    tools {
        terraform 'terraform'
    }
    parameters {
        choice(name: 'action', choices: ['apply', 'destroy'], description: 'Select the action to perform')
    }
    triggers {
        pollSCM('* * * * *') // Runs every minute
    }
    environment {
        SLACKCHANNEL = 'auto-discovery-pipeline-alerts'
        SLACKCREDENTIALS = credentials('slack-cred')
    }
   
    stages {
        stage('Secret Scan') {
            steps {
                script {
                    // Scans the working tree and git history; findings are redacted in the log
                    def gitleaksStatus = sh(
                        script: '''docker run --rm --user $(id -u):$(id -g) -v "$PWD":/repo zricethezav/gitleaks:v8.18.4 \
                            detect --source /repo --redact --verbose \
                            --report-format json --report-path /repo/gitleaks-report.json''',
                        returnStatus: true
                    )
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                    if (gitleaksStatus != 0) {
                        error 'Gitleaks found hardcoded secrets - rotate them and remove them from the repo'
                    }
                }
            }
        }
        stage('IAC Scan') {
            steps {
                script {
                    sh 'pip3 install --user checkov'
                    def checkovStatus = sh(script: 'export PATH=$PATH:$HOME/.local/bin && checkov -d . -o cli --quiet > checkov-results.txt', returnStatus: true)
                    archiveArtifacts artifacts: 'checkov-results.txt', allowEmptyArchive: true
                    // if (checkovStatus != 0) {
                    //     error 'Checkov found some issues'
                    // }
                }
            }
        }
        stage('Terraform Init') {  // Fixed spelling
            steps {
                sh 'terraform init'
            }
        }
        stage('Terraform format') {
            steps {
                sh 'terraform fmt --recursive'
            }
        }
        stage('Terraform validate') {
            steps {
                sh 'terraform validate'
            }
        }
        stage('Terraform plan') {
            steps {
                sh 'terraform plan'
            }
        }
        stage('Terraform action') {
            steps {
                script {
                    sh "terraform ${params.action} -auto-approve"
                }
            }
        }
    }
    post {
        always {
            script {
                slackSend(
                    channel: SLACKCHANNEL,
                    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
                    message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) has been completed."
                )
            }
        }
        failure {
            slackSend(
                channel: SLACKCHANNEL,
                color: 'danger',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' has failed. Check console output at ${env.BUILD_URL}."
            )
        }
        success {
            slackSend(
                channel: SLACKCHANNEL,
                color: 'good',
                message: "Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' completed successfully. Check console output at ${env.BUILD_URL}."
            )
        }
    }
}
 
