pipeline {
    agent { label 'slave' }

    parameters {
        string(
            name: 'VERSION',
            defaultValue: '1.0.0',
            description: 'Release version'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_REPOSITORY = "${ECR_REPOSITORY_URL}"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build(
                        "${ECR_REPOSITORY}:${IMAGE_TAG}",
                        "--build-arg BUILD_NUMBER=${BUILD_NUMBER} -f app/Dockerfile app/"
                    )
                    sh "docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest"
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    sh '''
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                    '''
                    sh "docker push ${ECR_REPOSITORY}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPOSITORY}:latest"
                }
            }
        }

        stage('Deploy to Dev') {
            steps {
                script {
                    def td = registerTaskDefinition('dev')
                    deployService('dev', td)
                }
            }
        }

        stage('Promote to Staging') {
            steps {
                script {
                    def td = registerTaskDefinition('staging')
                    deployService('staging', td)
                }
            }
        }

        stage('Approve Production') {
            input {
                message "Promote build #${BUILD_NUMBER} to production?"
                ok "Approve"
                submitter "admin"
            }
        }

        stage('Promote to Production') {
            steps {
                script {
                    def td = registerTaskDefinition('prod')
                    deployService('prod', td)
                }
            }
        }
    }

    post {
        success {
            echo """
            ┌──────────────────────────────────────┐
            │  Promotion Complete!                  │
            │                                      │
            │  Build: #${BUILD_NUMBER}              │
            │  Version: ${params.VERSION}           │
            │  Image: ${ECR_REPOSITORY}:${IMAGE_TAG}│
            │                                      │
            │  Dev:     https://testing.flowharbor.in│
            │  Staging: https://staging.flowharbor.in│
            │  Prod:    https://flowharbor.in       │
            └──────────────────────────────────────┘
            """
        }
        failure {
            echo "Promotion failed at ${env.STAGE_NAME}"
        }
    }
}

def registerTaskDefinition(envName) {
    def family = "flowharbor-${envName}"
    def cluster = "flowharbor-cluster"

    def currentTd = sh(
        script: "aws ecs describe-task-definition --task-definition ${family}",
        returnStdout: true
    ).trim()

    def definition = readJSON text: currentTd
    def containerDefs = definition.taskDefinition.containerDefinitions

    containerDefs[0].image = "${ECR_REPOSITORY}:latest"
    containerDefs[0].environment = [
        [name: "ENV", value: envName],
        [name: "VERSION", value: params.VERSION],
        [name: "BUILD_NUMBER", value: "${BUILD_NUMBER}"]
    ]

    def newTd = sh(
        script: """
            aws ecs register-task-definition \
                --family ${family} \
                --task-role-arn ${definition.taskDefinition.taskRoleArn} \
                --execution-role-arn ${definition.taskDefinition.executionRoleArn} \
                --network-mode ${definition.taskDefinition.networkMode} \
                --requires-compatibilities ${definition.taskDefinition.requiresCompatibilities.join(' ')} \
                --cpu ${definition.taskDefinition.cpu} \
                --memory ${definition.taskDefinition.memory} \
                --container-definitions '${containerDefs}'
        """,
        returnStdout: true
    ).trim()

    return readJSON(text: newTd).taskDefinition.taskDefinitionArn
}

def deployService(envName, taskDefinitionArn) {
    def cluster = "flowharbor-cluster"
    def serviceName = "flowharbor-${envName}"

    sh """
        aws ecs update-service \
            --cluster ${cluster} \
            --service ${serviceName} \
            --task-definition ${taskDefinitionArn} \
            --force-new-deployment
    """

    sh """
        aws ecs wait services-stable \
            --cluster ${cluster} \
            --services ${serviceName}
    """
}
