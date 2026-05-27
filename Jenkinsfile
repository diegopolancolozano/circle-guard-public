// =============================================================================
// CircleGuard — CI/CD Pipeline
//
// PIPELINE_MODE:
//   reduced  → Checkout + Compile + Unit/Integration Tests + SonarQube
//   full     → reduced + Docker push + K8s deploy + Smoke/E2E/Perf/Security
//
// CLOUD_TARGET (full mode only):
//   local         → kubeconfig from Jenkins credential 'kubeconfig-credentials'
//   digitalocean  → kubeconfig from Jenkins credential 'kubeconfig-do-credentials'
//   gcp           → GKE auth via SA JSON credential 'gcp-sa-credentials'
//   multi         → run the pipeline twice (once with DO, once with GCP)
//
// Required Jenkins credentials:
//   dockerhub-credentials     — Username/Password (DockerHub)
//   kubeconfig-credentials    — Secret file (kubeconfig for local/DO)
//   kubeconfig-do-credentials — Secret file (kubeconfig for DOKS)
//   gcp-sa-credentials        — Secret file (GCP Service Account JSON)
//
// Companion pipeline for infrastructure provisioning:
//   Jenkinsfile.infra  → runs Terraform (terraform-gcp + terraform-k8s)
// =============================================================================
pipeline {
    agent any

    parameters {
        choice(name: 'PIPELINE_MODE', choices: ['reduced', 'full'], description: 'reduced = build + integration tests only; full = deploy, performance, evidence and release flow')
        choice(name: 'CLOUD_TARGET', choices: ['local', 'digitalocean', 'gcp', 'multi'], description: 'Cloud execution target for full mode. local = kubeconfig local, digitalocean = DOKS kubeconfig, gcp = GKE kubeconfig, multi = both DO and GCP strategy')
        string(name: 'TEARDOWN_AFTER_MINUTES', defaultValue: '5', description: 'Minutes to wait before tearing down deployed environment. Use 0 to prompt manually and keep it running until teardown is scheduled.')
    }

    options {
        timestamps()
        timeout(time: 90, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        DOCKER_IMAGE_PREFIX = "diegopolancolozano/circleguard"
        DOCKER_CREDENTIALS_ID = "dockerhub-credentials"
        KUBECONFIG_CREDENTIALS_ID = "kubeconfig-credentials"
        QR_SECRET_CREDENTIALS_ID = "qr-secret-value"
        DOCKERHUB_EMAIL = "devops@circleguard.local"
    }

    stages {

        // ------------------------------------------------------------------ //
        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        // ------------------------------------------------------------------ //
        stage("Prepare") {
            steps {
                sh "chmod +x scripts/ci/*.sh"
            }
        }

        // ------------------------------------------------------------------ //
        // Determine deploy environment and image tags based on branch name.
        stage("Resolve Environment") {
            steps {
                script {
                    env.PIPELINE_MODE = (params.PIPELINE_MODE ?: 'reduced').trim()
                    env.CLOUD_TARGET = (params.CLOUD_TARGET ?: 'local').trim()
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

        stage("Resolve Cloud Target") {
            steps {
                script {
                    echo "PIPELINE_MODE=${env.PIPELINE_MODE}"
                    echo "CLOUD_TARGET=${env.CLOUD_TARGET}"

                    if (!(env.CLOUD_TARGET in ['local', 'digitalocean', 'gcp', 'multi'])) {
                        error "Invalid CLOUD_TARGET='${env.CLOUD_TARGET}'. Allowed: local, digitalocean, gcp, multi"
                    }

                    if (env.PIPELINE_MODE == 'reduced' && env.CLOUD_TARGET != 'local') {
                        echo "Reduced mode selected: cloud target is informational only; no deploy stages will run."
                    }

                    if (env.CLOUD_TARGET == 'digitalocean') {
                        env.KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-do-credentials'
                    } else if (env.CLOUD_TARGET == 'gcp') {
                        env.KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-gcp-credentials'
                    } else if (env.CLOUD_TARGET == 'local') {
                        env.KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-credentials'
                    } else if (env.CLOUD_TARGET == 'multi') {
                        // Multi-cloud run: select one kubeconfig per execution. Use two runs (DO + GCP).
                        env.KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-gcp-credentials'
                    }

                    echo "KUBECONFIG_CREDENTIALS_ID=${env.KUBECONFIG_CREDENTIALS_ID}"

                    if (env.PIPELINE_MODE == 'full') {
                        if (env.CLOUD_TARGET == 'digitalocean') {
                            echo "Full mode on DigitalOcean: expecting DOKS kubeconfig in Jenkins credential '${env.KUBECONFIG_CREDENTIALS_ID}'."
                        } else if (env.CLOUD_TARGET == 'gcp') {
                            echo "Full mode on GCP: expecting GKE kubeconfig in Jenkins credential '${env.KUBECONFIG_CREDENTIALS_ID}'."
                        } else if (env.CLOUD_TARGET == 'multi') {
                            echo "Full mode multi-cloud (DO + GCP): run twice with CLOUD_TARGET=digitalocean and CLOUD_TARGET=gcp."
                            echo "Use docs/MULTICLOUD_GCP_DO.md for rollout strategy and staged adoption."
                        }
                    }
                }
            }
        }

        stage("Compute Version") {
            steps {
                script {
                    env.RELEASE_VERSION = sh(script: "scripts/ci/semver-from-git.sh", returnStdout: true).trim()
                    sh "mkdir -p build"
                    writeFile file: "build/semver.txt", text: "${env.RELEASE_VERSION}\n"
                    echo "RELEASE_VERSION=${env.RELEASE_VERSION}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "build/semver.txt", allowEmptyArchive: true
                }
            }
        }

        stage("Ask Teardown Minutes") {
            when {
                expression { return env.DEPLOY_ENV?.trim() && env.PIPELINE_MODE == 'full' }
            }
            steps {
                script {
                    def raw = (params.TEARDOWN_AFTER_MINUTES ?: '0').trim()
                    if (raw == '0') {
                        def manualCauses = []
                        try {
                            manualCauses = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
                        } catch (ignored) {
                            manualCauses = []
                        }

                        if (manualCauses) {
                            def ans = input message: "¿Cuántos minutos antes de teardown para ${env.DEPLOY_ENV}?", parameters: [string(name: 'TEARDOWN_INPUT', defaultValue: '5', description: 'Minutos antes de teardown')]
                            env.TEARDOWN_AFTER_MINUTES = (ans ?: '5').trim()
                        } else {
                            env.TEARDOWN_AFTER_MINUTES = '5'
                            echo "Build triggered by push or non-manual cause; defaulting teardown to 5 minutes."
                        }
                    } else {
                        env.TEARDOWN_AFTER_MINUTES = raw
                    }
                    echo "TEARDOWN_AFTER_MINUTES=${env.TEARDOWN_AFTER_MINUTES}"
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Compile, run all tests, generate coverage report.
        // The compiled classes are reused by 'Build & Push Images' (no second clean).
        stage("Build & Test") {
            steps {
                sh "./gradlew clean test jacocoTestReport --info"
            }
            post {
                always {
                    archiveArtifacts artifacts: "**/build/reports/jacoco/test/**, **/build/reports/tests/test/**", allowEmptyArchive: true
                }
            }
        }

        stage("Static Analysis (SonarQube)") {
            when {
                expression { return env.PIPELINE_MODE in ['reduced', 'full'] }
            }
            steps {
                script {
                    def sonarHost = (env.SONAR_HOST_URL ?: "").trim()
                    def sonarToken = (env.SONAR_TOKEN ?: "").trim()
                    if (sonarHost && sonarToken) {
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh "./gradlew sonarqube -Dsonar.host.url=${sonarHost} -Dsonar.login=${sonarToken}"
                        }
                    } else {
                        echo "Skipping SonarQube: SONAR_HOST_URL or SONAR_TOKEN not set."
                    }
                }
            }
        }

        stage("Build & Push Images") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.IMAGE_TAGS?.trim() }
            }
            steps {
                script {
                    if (env.CLOUD_TARGET in ['gcp', 'multi']) {
                        withCredentials([file(credentialsId: env.GCP_SA_CREDENTIALS_ID, variable: 'GCP_SA_FILE')]) {
                            sh """
                                KUBECONFIG="${env.KUBECONFIG_PATH}" \
                                GCP_SA_FILE="${GCP_SA_FILE}" \
                                GCP_PROJECT="${env.RESOLVED_GCP_PROJECT}" \
                                GKE_CLUSTER_NAME="${env.RESOLVED_GKE_CLUSTER_NAME}" \
                                GKE_CLUSTER_LOCATION="${env.RESOLVED_GKE_LOCATION}" \
                                scripts/ci/ensure-gke-access.sh
                            """
                        }
                    } else {
                        withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBE_FILE')]) {
                            sh """
                                cp "\${KUBE_FILE}" "${env.KUBECONFIG_PATH}"
                                chmod 600 "${env.KUBECONFIG_PATH}"
                            """
                        }
                    }
                    // Sanity check
                    withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                        sh "kubectl version --client --short || kubectl version --client"
                        sh "kubectl config current-context"
                    }
                }
            }
        }

        stage("Trivy Scan") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.IMAGE_TAGS?.trim() }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh "scripts/ci/run-trivy.sh '${IMAGE_TAGS}' '${DOCKER_IMAGE_PREFIX}'"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/security/results/trivy-*.json, tests/security/results/trivy-*.txt", allowEmptyArchive: true
                }
            }
        }

        stage("Ensure Flyway Baseline") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    script {
                        // Only target services that actually run Flyway migrations.
                        def flywayServices = [
                            "circleguard-auth-service",
                            "circleguard-identity-service",
                            "circleguard-promotion-service",
                            "circleguard-gateway-service",
                            "circleguard-file-service"
                        ]
                        def namespaces = (env.BRANCH_NAME == 'main') ? ['stage', 'prod'] : [env.DEPLOY_ENV]
                        for (ns in namespaces) {
                            for (svc in flywayServices) {
                                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                    sh "kubectl -n ${ns} set env deployment/${svc} SPRING_FLYWAY_BASELINE_ON_MIGRATE=true 2>/dev/null || true"
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Deploy to dev or stage (main branch deploys stage first; prod is gated).
        stage("Deploy") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    script {
                        def targetEnv = (env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV
                        sh "scripts/ci/k8s-deploy.sh ${targetEnv}"
                    }
                }
            }
        }

        stage("Deploy Monitoring") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-deploy-monitoring.sh"
                    }
                }
            }
        }

        stage("Testing & Performance") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-deploy-monitoring.sh"
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Smoke tests: run inside the cluster (curl pod) — only on stage branch.
        stage("Smoke Tests") {
            when {
                allOf {
                    branch "stage"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-smoke-tests.sh stage"
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        // E2E tests via port-forward — only on main branch (against stage deploy).
        stage("E2E Tests") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/run-e2e-tests.sh stage"
                    }
                }
            }
            post {
                always {
                    junit testResults: "**/build/test-results/test/*.xml", allowEmptyResults: true
                }
            }
        }

        stage("Security Scan (OWASP ZAP)") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    script {
                        def scanEnv = (env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh "scripts/ci/run-owasp-zap.sh ${scanEnv}"
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/security/results/zap-*.html, tests/security/results/zap-*.json, tests/security/results/zap-*.md", allowEmptyArchive: true
                }
            }
        }

        stage("Stage Evidence") {
            when {
                allOf {
                    branch "stage"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-stage-evidence.sh stage stage-evidence.txt"
                    }
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: "stage-evidence.txt", allowEmptyArchive: true
                }
            }
        }

        stage("Approve Prod Deploy") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                input message: "Approve production deploy ${env.RELEASE_VERSION ?: 'unknown'}?"
            }
        }

        stage("Deploy Prod") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    sh "scripts/ci/k8s-deploy.sh prod"
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Generate Release Notes") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                sh "scripts/ci/generate-release-notes.sh"
            }
            post {
                success {
                    archiveArtifacts artifacts: "release-notes.md", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Scale dev/stage to zero after TEARDOWN_AFTER_MINUTES.
        // Uses KUBECONFIG_PATH (a workspace file) so the nohup background process
        // can access it after this stage — unlike withCredentials temp files.
        stage("Scheduled Teardown") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV in ["dev", "stage"] }
            }
            steps {
                script {
                    def raw = (env.TEARDOWN_AFTER_MINUTES ?: '0').trim()
                    if (!(raw ==~ /^\d+$/)) {
                        error "TEARDOWN_AFTER_MINUTES must be a non-negative integer. Got: '${raw}'"
                    }
                    int minutes = raw as Integer
                    if (minutes > 0) {
                        echo "Scheduling teardown of '${env.DEPLOY_ENV}' in ${minutes} minute(s)."
                        sh """
                            nohup sh -c \
                              'sleep ${minutes}m && KUBECONFIG=${env.KUBECONFIG_PATH} scripts/ci/k8s-teardown.sh ${env.DEPLOY_ENV}' \
                              > /tmp/teardown-${env.DEPLOY_ENV}-${env.BUILD_NUMBER}.log 2>&1 &
                        """
                    } else {
                        echo "TEARDOWN_AFTER_MINUTES=0 — environment '${env.DEPLOY_ENV}' will remain running."
                    }
                }
            }
        }

    } // end stages

    post {
        always {
            // Clean up the workspace kubeconfig so tokens don't linger on disk.
            sh "rm -f '${env.KUBECONFIG_PATH ?: '/dev/null'}' 2>/dev/null || true"
        }
        failure {
            sh "scripts/ci/notify-webhook.sh failure || true"
        }
        unstable {
            sh "scripts/ci/notify-webhook.sh unstable || true"
        }
        success {
            sh "scripts/ci/notify-webhook.sh success || true"
        }
    }

    post {
        failure {
            sh "scripts/ci/notify-webhook.sh failure"
        }
        unstable {
            sh "scripts/ci/notify-webhook.sh unstable"
        }
    }
}
