pipeline {
    agent { label 'slave' }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_REPOSITORY = credentials('ecr-repository-url')
        CLUSTER_NAME = 'flowharbor-cluster'
        GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        GIT_BRANCH = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
        GIT_AUTHOR = sh(script: "git log -1 --pretty=format:'%an'", returnStdout: true).trim()
        PIPELINE_URL = "${env.BUILD_URL}"
        TIMESTAMP = sh(script: "date -u +'%Y-%m-%dT%H:%M:%SZ'", returnStdout: true).trim()
    }

    stages {
        stage('Build') {
            steps {
                script {
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "  Building Docker image"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "  Repo:    ${ECR_REPOSITORY}"
                    echo "  Tag:     ${BUILD_NUMBER}"
                    echo "  Branch:  ${GIT_BRANCH}"
                    echo "  Commit:  ${GIT_COMMIT_SHORT}"
                    echo "  Author:  ${GIT_AUTHOR}"

                    sh "docker build --build-arg BUILD_NUMBER=${BUILD_NUMBER} -t ${ECR_REPOSITORY}:${BUILD_NUMBER} -f app/Dockerfile app/"
                    sh "docker tag ${ECR_REPOSITORY}:${BUILD_NUMBER} ${ECR_REPOSITORY}:latest"

                    def imageInspect = sh(
                        script: "docker inspect ${ECR_REPOSITORY}:${BUILD_NUMBER} --format '{{.CreatedSince}}'",
                        returnStdout: true
                    ).trim()
                    echo "  Built:   ${imageInspect}"
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

                    def digest = sh(
                        script: "aws ecr describe-images --repository-name ${ECR_REPOSITORY.split('/')[1]} --image-ids imageTag=${BUILD_NUMBER} --query 'imageDetails[0].imageDigest' --output text",
                        returnStdout: true
                    ).trim()

                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "  Pushed to ECR"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "  Image: ${ECR_REPOSITORY}:${BUILD_NUMBER}"
                    echo "  Digest: ${digest}"
                }
            }
        }

        stage('Deploy to Dev') {
            steps {
                script { promote('dev') }
            }
        }

        stage('Approve Staging') {
            input {
                message "Promote build #${BUILD_NUMBER} (${GIT_COMMIT_SHORT}) to staging?"
                ok "Promote to Staging"
                submitter 'admin'
            }
        }

        stage('Promote to Staging') {
            steps {
                script { promote('staging') }
            }
        }

        stage('Approve Production') {
            input {
                message "Promote build #${BUILD_NUMBER} (${GIT_COMMIT_SHORT}) to production?"
                ok "Promote to Production"
                submitter 'admin'
            }
        }

        stage('Promote to Production') {
            steps {
                script { promote('prod') }
            }
        }
    }

    post {
        success {
            script {
                def envUrl = [
                    dev:     "https://testing.flowharbor.in",
                    staging: "https://staging.flowharbor.in",
                    prod:    "https://flowharbor.in"
                ]
                echo ""
                echo "╔══════════════════════════════════════════════════╗"
                echo "║           PROMOTION COMPLETE                    ║"
                echo "╠══════════════════════════════════════════════════╣"
                echo "║  Build:   #${BUILD_NUMBER.padLeft(6)}                          ║"
                echo "║  Version: ${params.VERSION?.padRight(28)}           ║"
                echo "║  Commit:  ${GIT_COMMIT_SHORT.padRight(28)}           ║"
                echo "║  Branch:  ${GIT_BRANCH.padRight(28)}           ║"
                echo "║  Author:  ${GIT_AUTHOR.padRight(28)}           ║"
                echo "║  Image:   ${ECR_REPOSITORY}:${BUILD_NUMBER}   ║"
                echo "╠══════════════════════════════════════════════════╣"
                echo "║  Dev:     https://testing.flowharbor.in  ║"
                echo "║  Staging: https://staging.flowharbor.in  ║"
                echo "║  Prod:    https://flowharbor.in          ║"
                echo "╠══════════════════════════════════════════════════╣"
                echo "║  Jenkins: ${PIPELINE_URL}  ║"
                echo "╚══════════════════════════════════════════════════╝"
                echo ""
            }
        }
        aborted {
            echo "Pipeline aborted at stage: ${env.STAGE_NAME}"
        }
        failure {
            echo "Pipeline failed at stage: ${env.STAGE_NAME}"
            currentBuild.result = 'FAILURE'
        }
    }
}

def promote(envName) {
    def family = "flowharbor-${envName}"
    def serviceName = "flowharbor-${envName}"

    def envLabel = [
        dev:     "Dev",
        staging: "Staging",
        prod:    "Production"
    ][envName]

    def envUrl = [
        dev:     "https://testing.flowharbor.in",
        staging: "https://staging.flowharbor.in",
        prod:    "https://flowharbor.in"
    ][envName]

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Promoting to ${envLabel} (${envName})"
    echo "  URL: ${envUrl}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
            [name: "BUILD_NUMBER", value: "${BUILD_NUMBER}"],
            [name: "GIT_COMMIT", value: GIT_COMMIT_SHORT],
            [name: "GIT_BRANCH", value: GIT_BRANCH],
            [name: "GIT_AUTHOR", value: GIT_AUTHOR],
            [name: "TIMESTAMP", value: TIMESTAMP],
            [name: "PIPELINE_URL", value: PIPELINE_URL]
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

    def tdResult = readJSON(text: newTd)
    def tdArn = tdResult.taskDefinition.taskDefinitionArn
    def revision = tdResult.taskDefinition.revision

    echo "  Task Definition: ${family}:${revision}"

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

    def serviceDesc = sh(
        script: "aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${serviceName} --query 'services[0].{running: runningCount,desired: desiredCount,status: status}' --output json",
        returnStdout: true
    ).trim()

    echo "  Status: ${serviceDesc}"
    echo "  ${envLabel}: ${envUrl}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
