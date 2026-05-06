pipeline {
    agent any

    options {
        timestamps()
    }

    environment {
        DOCKER_IMAGE_PREFIX = "diegopolancolozano/circleguard"
        DOCKER_CREDENTIALS_ID = "dockerhub-credentials"
        KUBECONFIG_CREDENTIALS_ID = "kubeconfig-credentials"
        QR_SECRET_CREDENTIALS_ID = "qr-secret-value"
        DOCKERHUB_EMAIL = "devops@circleguard.local"
        GCP_PROJECT = "1026376319321"
        GKE_CLUSTER_NAME = "circle-guard-cluster"
        GKE_CLUSTER_LOCATION = "us-central1"
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
                    } else if (env.BRANCH_NAME == "main") {
                        env.DEPLOY_ENV = "prod"
                        env.IMAGE_TAGS = "stage,prod"
                    } else {
                        env.DEPLOY_ENV = ""
                        env.IMAGE_TAGS = ""
                    }
                }
            }
        }

        stage("Build & Unit Tests") {
            steps {
                sh "./gradlew :services:circleguard-auth-service:test :services:circleguard-identity-service:test :services:circleguard-promotion-service:test :services:circleguard-gateway-service:test :services:circleguard-form-service:test :services:circleguard-notification-service:test"
            }
        }

        stage("Terraform Bootstrap K8s") {
            when {
                expression { return env.IMAGE_TAGS?.trim() }
            }
            steps {
                withCredentials([
                usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID,
                usernameVariable: "DOCKERHUB_USERNAME",
                passwordVariable: "DOCKERHUB_PASSWORD"),

                file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID,
                variable: "KUBECONFIG"),

                string(credentialsId: env.QR_SECRET_CREDENTIALS_ID,
                variable: "QR_SECRET"),

                file(credentialsId: 'gcp-sa-json',
                variable: 'GCP_SA_FILE')
                ]) {
                sh "scripts/ci/terraform-bootstrap.sh"
            }
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
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-deploy.sh dev"
                }
            }
        }

        stage("Deploy Stage") {
            when {
                branch "stage"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-deploy.sh stage"
                }
            }
        }

        stage("Stage Smoke Tests") {
            when {
                branch "stage"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-smoke-tests.sh stage"
                }
            }
        }

        stage("Stage Evidence") {
            when {
                branch "stage"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-stage-evidence.sh stage stage-evidence.txt"
                    archiveArtifacts artifacts: "stage-evidence.txt", onlyIfSuccessful: true
                }
            }
        }

        stage("Deploy Stage For Main Validation") {
            when {
                branch "main"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-deploy.sh stage"
                }
            }
        }

        stage("Main E2E Tests") {
            when {
                branch "main"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/run-e2e-tests.sh stage"
                }
            }
        }

        stage("Main Performance Tests") {
            when {
                branch "main"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/run-locust.sh stage"
                }
            }
        }

        stage("Deploy Prod") {
            when {
                branch "main"
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-deploy.sh prod"
                }
            }
        }

        stage("Generate Release Notes") {
            when {
                branch "main"
            }
            steps {
                sh "scripts/ci/generate-release-notes.sh"
                archiveArtifacts artifacts: "release-notes.md", onlyIfSuccessful: true
            }
        }
    }
}
