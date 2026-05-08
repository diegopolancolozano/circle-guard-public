pipeline {
    agent any


    parameters {
        booleanParam(name: 'TEARDOWN', defaultValue: false, description: 'Remove the local Kubernetes namespaces and workloads')
    }

    environment {
        DOCKER_IMAGE_PREFIX = "diegoapolancol/circleguard"
        DOCKER_CREDENTIALS_ID = "dockerhub-credentials"
        DOCKERHUB_EMAIL = "devops@circleguard.local"
        TEARDOWN = "false"
        KUBECONFIG = "/var/jenkins_home/.kube/config"
    }

    stages {
        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Prepare") {
            steps {
                sh "chmod +x scripts/ci/*.sh"
            }
        }

        stage("Resolve Environment") {
            steps {
                script {
                    if (env.BRANCH_NAME == "dev") {
                        env.DEPLOY_ENV = "dev"
                        env.IMAGE_TAGS = "dev"
                    } else if (env.BRANCH_NAME == "stage") {
                        env.DEPLOY_ENV = "stage"
                        env.IMAGE_TAGS = "stage"
                    } else if (env.BRANCH_NAME == "master" || env.BRANCH_NAME == "main") {
                        env.DEPLOY_ENV = "master"
                        env.IMAGE_TAGS = "master"
                    } else {
                        env.DEPLOY_ENV = ""
                        env.IMAGE_TAGS = ""
                    }
                }
            }
        }

        stage("Build & Unit Tests") {
            steps {
                sh "./gradlew clean :services:circleguard-auth-service:bootJar :services:circleguard-identity-service:bootJar :services:circleguard-promotion-service:bootJar :services:circleguard-gateway-service:bootJar :services:circleguard-dashboard-service:bootJar :services:circleguard-file-service:bootJar -x test"
            }
        }

        stage("Prepare Kubernetes") {
            when {
                expression { return env.IMAGE_TAGS?.trim() }
            }
            steps {
                sh "kubectl config current-context"
            }
        }

        stage("Build & Push Images") {
            when {
                expression { return env.IMAGE_TAGS?.trim() }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: "DOCKERHUB_USERNAME", passwordVariable: "DOCKERHUB_PASSWORD")]) {
                    sh "scripts/ci/build-and-push-images.sh '${IMAGE_TAGS}' '${DOCKER_IMAGE_PREFIX}' '${DOCKERHUB_USERNAME}' '${DOCKERHUB_PASSWORD}'"
                }
            }
        }

        stage("Deploy Dev") {
            when {
                branch "dev"
            }
            steps {
                sh "scripts/ci/k8s-deploy.sh dev"
            }
        }

        stage("Deploy Stage") {
            when {
                branch "stage"
            }
            steps {
                sh "scripts/ci/k8s-deploy.sh stage"
            }
        }

        stage("Deploy Master") {
            when {
                anyOf {
                    branch "master"
                    branch "main"
                }
            }
            steps {
                sh "scripts/ci/k8s-deploy.sh master"
            }
        }

        stage("Stage Smoke Tests") {
            when {
                branch "stage"
            }
            steps {
                sh "scripts/ci/k8s-smoke-tests.sh stage"
            }
        }

        stage("Stage E2E Tests") {
            when {
                branch "stage"
            }
            steps {
                sh "scripts/ci/run-e2e-tests.sh stage"
            }
        }

        stage("Stage Performance Tests") {
            when {
                branch "stage"
            }
            steps {
                sh "scripts/ci/run-locust.sh stage"
            }
        }

        stage("Master E2E Tests") {
            when {
                anyOf {
                    branch "master"
                    branch "main"
                }
            }
            steps {
                sh "scripts/ci/run-e2e-tests.sh master"
            }
        }

        stage("Master Performance Tests") {
            when {
                anyOf {
                    branch "master"
                    branch "main"
                }
            }
            steps {
                sh "scripts/ci/run-locust.sh master"
            }
        }

        stage("Generate Release Notes") {
            when {
                anyOf {
                    branch "master"
                    branch "main"
                }
            }
            steps {
                sh "scripts/ci/generate-release-notes.sh"
                archiveArtifacts artifacts: "release-notes.md", onlyIfSuccessful: true
            }
        }

        stage("Teardown All Infrastructure") {
            when {
                expression { return env.TEARDOWN == 'true' }
            }
            steps {
                sh "scripts/ci/teardown-all.sh"
            }
        }
    }
}
