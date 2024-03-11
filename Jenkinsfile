pipeline {
    agent any

    parameters {
        choice(name: 'PIPELINE_TYPE', choices: ['frontend', 'backend'], description: 'Select the pipeline type to run')
    }

    tools {
        nodejs 'nodejs'
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_DEFAULT_REGION = 'ap-south-1'
        AWS_ECR_1 = credentials('frontend')
        AWS_ECR_2 = credentials('backend')
        REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/"
        GIT_REPO_NAME = 'DevSecOps-CICD'
        GIT_USER_NAME = 'Bhavin-Bhesaniya'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Git') {
            steps {
                git branch: 'main', url: 'https://github.com/Bhavin-Bhesaniya/DevSecOps-CICD.git'
            }
        }

        stage('Sonarqube Analysis') {
            steps {
                script {
                    def codeDir = params.PIPELINE_TYPE == 'frontend' ? 'Application-Code/frontend' : 'Application-Code/backend'
                    def projectName = params.PIPELINE_TYPE == 'frontend' ? 'three-tier-frontend' : 'three-tier-backend'
                    def projectKey = params.PIPELINE_TYPE == 'frontend' ? 'three-tier-frontend' : 'three-tier-backend'

                    dir(codeDir) {
                        withSonarQubeEnv('sonarqube-server') {
                            sh """ $SCANNER_HOME/bin/sonar-scanner \
                            -Dsonar.projectName=${projectName} \
                            -Dsonar.projectKey=${projectKey} """
                        }
                    }
                }
            }
        }

        // stage('Quality Check') {
        //     steps {
        //         waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
        //     }
        // }

        stage('OWASP Dependency-Check Scan') {
            steps {
                script {
                    def codeDir = params.PIPELINE_TYPE == 'frontend' ? 'Application-Code/frontend' : 'Application-Code/backend'

                    dir(codeDir) {
                        dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                        dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                    }
                }
            }
        }


        stage('Trivy File Scan') {
            steps {
                script {
                    def codeDir = params.PIPELINE_TYPE == 'frontend' ? 'Application-Code/frontend' : 'Application-Code/backend'
                    def outputFile = params.PIPELINE_TYPE == 'frontend' ? 'trivyfs-frontend-job-${BUILD_NUMBER}-${BUILD_ID}.txt' : 'trivyfs-backend-job-${BUILD_NUMBER}-${BUILD_ID}.txt'

                    dir(codeDir) {
                        sh "trivy fs . > ../../${outputFile}"
                    }
                }
            }
        }

        stage('Docker Image Build') {
            steps {
                script {
                    def codeDir = params.PIPELINE_TYPE == 'frontend' ? 'Application-Code/frontend' : 'Application-Code/backend'
                    def ecrRepoName = params.PIPELINE_TYPE == 'frontend' ? "${AWS_ECR_1}" : "${AWS_ECR_2}"

                    dir(codeDir) {
                        sh 'docker system prune -f'
                        sh 'docker container prune -f'
                        sh "docker build -t ${ecrRepoName} ."
                    }
                }
            }
        }

        stage('Trivy Scan Image') {
            steps {
                script {
                    def ecrRepoName = params.PIPELINE_TYPE == 'frontend' ? "${AWS_ECR_1}" : "${AWS_ECR_2}"
                    def outputFile = params.PIPELINE_TYPE == 'frontend' ? 'trivyimage-frontend-${BUILD_NUMBER}-${BUILD_ID}.txt' : 'trivyimage-backend-${BUILD_NUMBER}-${BUILD_ID}.txt'

                    sh "trivy image ${ecrRepoName} > ${outputFile}"
                }
            }
        }

        // Backend ECR Image Pushing
        stage("ECR Image Pushing") {
            steps {
                script {
                    def ecrRepoName = params.PIPELINE_TYPE == 'frontend' ? "${AWS_ECR_1}-repo" : "${AWS_ECR_2}-repo"
                    def tagName = "${REPOSITORY_URI}${ecrRepoName}:${BUILD_NUMBER}"

                    sh 'aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URI}'
                    sh "docker tag ${ecrRepoName} ${tagName}"
                    sh "docker push ${tagName}"
                }
            }
        }
        stage('Update Deployment file') {
            steps {
                script {
                    def deploymentDir = params.PIPELINE_TYPE == 'frontend' ? 'Kubernetes-Manifests-file/Frontend' : 'Kubernetes-Manifests-file/Backend'
                    def ecrRepoName = params.PIPELINE_TYPE == 'frontend' ? "${AWS_ECR_1}-repo" : "${AWS_ECR_2}-repo"

                    dir(deploymentDir) {
                        withCredentials([string(credentialsId: 'github', variable: 'github-personal-access-token')]) {
                            sh '''
                            git config user.email "bkbhesaniya11@gmail.com"
                            git config user.name "Bhavin Bhesaniya"
                            BUILD_NUMBER=${BUILD_NUMBER}
                            echo $BUILD_NUMBER
                            imageTag=$(grep -oP '(?<=frontend:)[^ ]+' deployment.yaml)
                            echo $imageTag
                            sed -i "s/${ecrRepoName}:${imageTag}/${ecrRepoName}:${BUILD_NUMBER}/" deployment.yaml
                            git add deployment.yaml
                            git commit -m "Update deployment Image to version \${BUILD_NUMBER}"
                            git push https://${github-personal-access-token}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} HEAD:main
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                def customPipelineName = params.PIPELINE_TYPE == 'frontend' ? "Frontend Pipeline" : "Backend Pipeline"
                emailext attachLog: true,
                    subject: "${customPipelineName} - '${currentBuild.result}'",
                    body: "Project: ${env.JOB_NAME}<br/>" +
                        "Pipeline: ${customPipelineName}<br/>" +
                        "Build Number: ${env.BUILD_NUMBER}<br/>" +
                        "URL: ${env.BUILD_URL}<br/>",
                    to: 'bkbhesaniya11@gmail.com',
                    attachmentsPattern: 'trivyfs-frontend*.txt, trivyimage*.txt'
            }
        }
    }
}