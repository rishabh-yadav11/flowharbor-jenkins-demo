pipeline {
    agent { label 'slave' }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_REPOSITORY = credentials('ecr-repository-url')
        CLUSTER_NAME = 'flowharbor-cluster'
    }

    stages {
        stage('Build') {
            steps {
                script {
                    sh "docker build --build-arg BUILD_NUMBER=${BUILD_NUMBER} -t ${ECR_REPOSITORY}:${BUILD_NUMBER} -f app/Dockerfile app/"
                    sh "docker tag ${ECR_REPOSITORY}:${BUILD_NUMBER} ${ECR_REPOSITORY}:latest"
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                    """
                    sh "docker push ${ECR_REPOSITORY}:${BUILD_NUMBER}"
                    sh "docker push ${ECR_REPOSITORY}:latest"
                }
            }
        }

        stage('Deploy to Dev') {
            steps {
                script {
                    promote('dev')
                }
            }
        }

        stage('Approve Staging') {
            input {
                message "Promote build #${BUILD_NUMBER} to staging?"
                ok "Promote to Staging"
                submitter 'admin'
            }
        }

        stage('Promote to Staging') {
            steps {
                script {
                    promote('staging')
                }
            }
        }

        stage('Approve Production') {
            input {
                message "Promote build #${BUILD_NUMBER} to production?"
                ok "Promote to Production"
                submitter 'admin'
            }
        }

        stage('Promote to Production') {
            steps {
                script {
                    promote('prod')
                }
            }
        }
    }

    post {
        success {
            echo """
            ┌────────────────────────────────────────────┐
            │  Promotion Complete                        │
            │                                            │
            │  Build:  #${BUILD_NUMBER}                   │
            │  Image:  ${ECR_REPOSITORY}:${BUILD_NUMBER}  │
            │                                            │
            │  Dev:     https://testing.flowharbor.in    │
            │  Staging: https://staging.flowharbor.in    │
            │  Prod:    https://flowharbor.in            │
            └────────────────────────────────────────────┘
            """
        }
        failure {
            error "Promotion failed at stage: ${env.STAGE_NAME}"
        }
    }
}

def promote(envName) {
    def family = "flowharbor-${envName}"
    def serviceName = "flowharbor-${envName}"

    def currentTd = sh(
        script: "aws ecs describe-task-definition --task-definition ${family}",
        returnStdout: true
    ).trim()

    def td = readJSON text: currentTd
    def containerDef = td.taskDefinition.containerDefinitions[0]

    def newContainerDef = [
        name: containerDef.name,
        image: "${ECR_REPOSITORY}:latest",
        essential: containerDef.essential,
        portMappings: containerDef.portMappings,
        logConfiguration: containerDef.logConfiguration,
        environment: [
            [name: "ENV", value: envName],
            [name: "VERSION", value: params.VERSION ?: "1.0.0"],
            [name: "BUILD_NUMBER", value: "${BUILD_NUMBER}"]
        ]
    ]

    def payload = [
        family: family,
        taskRoleArn: td.taskDefinition.taskRoleArn,
        executionRoleArn: td.taskDefinition.executionRoleArn,
        networkMode: td.taskDefinition.networkMode,
        requiresCompatibilities: td.taskDefinition.requiresCompatibilities,
        cpu: td.taskDefinition.cpu,
        memory: td.taskDefinition.memory,
        containerDefinitions: [newContainerDef]
    ]

    writeJSON file: 'td.json', json: payload

    def newTd = sh(
        script: "aws ecs register-task-definition --cli-input-json file://td.json",
        returnStdout: true
    ).trim()

    def tdArn = readJSON(text: newTd).taskDefinition.taskDefinitionArn

    sh """
        aws ecs update-service \
            --cluster ${CLUSTER_NAME} \
            --service ${serviceName} \
            --task-definition ${tdArn} \
            --force-new-deployment
    """

    sh """
        aws ecs wait services-stable \
            --cluster ${CLUSTER_NAME} \
            --services ${serviceName}
    """
}
