pipeline {
    agent any

    parameters {
        string(name: 'TEARDOWN_AFTER_MINUTES', defaultValue: '0', description: 'Minutes to wait before tearing down deployed environment. Use 0 to keep it running.')
    }

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

        stage("Build & Integration Tests") {
            steps {
                sh "./gradlew clean test --info"
            }
        }

        stage("Terraform Bootstrap K8s") {
            when {
                expression { return env.IMAGE_TAGS?.trim() }
            }
            steps {
                withCredentials([
                    usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: "DOCKERHUB_USERNAME", passwordVariable: "DOCKERHUB_PASSWORD"),
                    file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG"),
                    string(credentialsId: env.QR_SECRET_CREDENTIALS_ID, variable: "QR_SECRET"),
                    // GCP service account JSON (Secret file in Jenkins credentials)
                    file(credentialsId: 'gcp-sa-json', variable: 'GCP_SA_FILE')
                ]) {
                    // Expose GCP vars to the script; configure them in the job (or as global env)
                    withCredentials([
                        usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: "DOCKERHUB_USERNAME", passwordVariable: "DOCKERHUB_PASSWORD"),
                        file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG"),
                        string(credentialsId: env.QR_SECRET_CREDENTIALS_ID, variable: "QR_SECRET"),
                        file(credentialsId: 'gcp-sa-json', variable: 'GCP_SA_FILE')
                    ]) {
                        sh "scripts/ci/terraform-bootstrap.sh"
                    }
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

        stage("Deploy") {
            when {
                expression { return env.DEPLOY_ENV?.trim() }
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    script {
                        if (env.BRANCH_NAME == "main") {
                            // Main branch: deploy to stage first, then prod
                            sh "scripts/ci/k8s-deploy.sh stage"
                        } else {
                            // Dev or stage branch: deploy to respective environment
                            sh "scripts/ci/k8s-deploy.sh ${env.DEPLOY_ENV}"
                        }
                    }
                }
            }
        }

        stage("Testing & Performance") {
            when {
                expression { return env.DEPLOY_ENV?.trim() }
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    script {
                        if (env.BRANCH_NAME == "stage") {
                            sh "scripts/ci/k8s-smoke-tests.sh stage"
                        } else if (env.BRANCH_NAME == "main") {
                            sh "scripts/ci/run-e2e-tests.sh stage"
                        }
                        
                        // Run performance tests for all deployable branches
                        sh "scripts/ci/run-locust.sh ${(env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV}"
                        sh "scripts/ci/performance-metrics.sh ${(env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV}"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/performance/results/locust-*.log, tests/performance/results/locust-*_stats.csv, tests/performance/results/locust-*_failures.csv, tests/performance/results/locust-*_exceptions.csv, tests/performance/results/metrics/*.md, tests/performance/results/metrics/*.json", allowEmptyArchive: true
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

        stage("Generate Release Notes") {
            when {
                branch "main"
            }
            steps {
                sh "scripts/ci/generate-release-notes.sh"
                archiveArtifacts artifacts: "release-notes.md", onlyIfSuccessful: true
            }
        }

        stage("Scheduled Teardown") {
            when {
                expression { return env.DEPLOY_ENV in ["dev", "stage"] }
            }
            steps {
                script {
                    def teardownRaw = (params.TEARDOWN_AFTER_MINUTES ?: "0").trim()
                    if (!(teardownRaw ==~ /^\d+$/)) {
                        error "TEARDOWN_AFTER_MINUTES must be a non-negative integer. Received: '${teardownRaw}'"
                    }

                    int teardownMinutes = teardownRaw as Integer
                    if (teardownMinutes > 0) {
                        echo "Teardown scheduled in ${teardownMinutes} minute(s) for env '${env.DEPLOY_ENV}'"
                        sleep time: teardownMinutes, unit: 'MINUTES'
                        withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                            sh "scripts/ci/k8s-teardown.sh ${env.DEPLOY_ENV}"
                        }
                    } else {
                        echo "TEARDOWN_AFTER_MINUTES=0, environment '${env.DEPLOY_ENV}' will remain up."
                    }
                }
            }
        }
    }
}
