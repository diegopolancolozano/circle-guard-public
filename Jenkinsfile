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
        choice(
            name: 'PIPELINE_MODE',
            choices: ['full', 'reduced'],
            description: 'full = deploy + smoke/perf/release flow; reduced = build + tests only'
        )
        choice(
            name: 'CLOUD_TARGET',
            choices: ['digitalocean', 'gcp', 'local', 'multi'],
            description: 'Target cloud. digitalocean = DOKS; gcp = GKE; multi = DO + GCP sequentially.'
        )
        string(
            name: 'GCP_PROJECT',
            defaultValue: '',
            description: '(GCP only) GCP project ID. Leave blank to use the value set in Resolve Cloud Target.'
        )
        string(
            name: 'GKE_CLUSTER_NAME',
            defaultValue: '',
            description: '(GCP only) GKE cluster name. Leave blank to use the per-environment default.'
        )
        string(
            name: 'GKE_CLUSTER_LOCATION',
            defaultValue: 'us-central1',
            description: '(GCP only) GKE cluster region/zone.'
        )
        string(
            name: 'TEARDOWN_AFTER_MINUTES',
            defaultValue: '5',
            description: 'Minutes to wait before scaling dev/stage to zero. Use 0 to keep running.'
        )
    }

    options {
        timestamps()
        timeout(time: 90, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        DOCKER_IMAGE_PREFIX    = "diegoapolancol/circleguard"
        DOCKER_CREDENTIALS_ID  = "dockerhub-credentials"
        DOCKERHUB_EMAIL        = "devops@circleguard.local"
        GCP_SA_CREDENTIALS_ID  = "gcp-sa-credentials"
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
                    env.PIPELINE_MODE = (params.PIPELINE_MODE ?: 'full').trim()
                    env.CLOUD_TARGET  = (params.CLOUD_TARGET  ?: 'digitalocean').trim()

                    // Webhook builds on deploy branches → always full + DO
                    def isWebhook = !currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
                    if (isWebhook && env.BRANCH_NAME in ['dev', 'stage', 'main']) {
                        env.PIPELINE_MODE = 'full'
                        if (env.CLOUD_TARGET == 'gcp') { env.CLOUD_TARGET = 'digitalocean' }
                        echo "Webhook build on ${env.BRANCH_NAME} → PIPELINE_MODE=full, CLOUD_TARGET=${env.CLOUD_TARGET}"
                    }

                    switch (env.BRANCH_NAME) {
                        case "dev":
                            env.DEPLOY_ENV  = "dev"
                            env.IMAGE_TAGS  = "dev"
                            break
                        case "stage":
                            env.DEPLOY_ENV  = "stage"
                            env.IMAGE_TAGS  = "stage"
                            break
                        case "main":
                            env.DEPLOY_ENV  = "prod"
                            env.IMAGE_TAGS  = "stage,prod"
                            break
                        default:
                            env.DEPLOY_ENV  = ""
                            env.IMAGE_TAGS  = ""
                    }

                    // A unique kubeconfig file written to the workspace so it
                    // persists across stages and is accessible to background nohup.
                    env.KUBECONFIG_PATH = "${env.WORKSPACE}/.kubeconfig-${env.BUILD_NUMBER}"

                    echo "PIPELINE_MODE=${env.PIPELINE_MODE} | CLOUD_TARGET=${env.CLOUD_TARGET} | BRANCH=${env.BRANCH_NAME} | DEPLOY_ENV=${env.DEPLOY_ENV}"
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Validate cloud target and set cloud-specific configuration.
        stage("Resolve Cloud Target") {
            steps {
                script {
                    if (!(env.CLOUD_TARGET in ['local', 'digitalocean', 'gcp', 'multi'])) {
                        error "Invalid CLOUD_TARGET='${env.CLOUD_TARGET}'. Allowed: local, digitalocean, gcp, multi"
                    }

                    // Choose kubeconfig credential ID for non-GKE clouds.
                    switch (env.CLOUD_TARGET) {
                        case "digitalocean":
                            env.KUBECONFIG_CREDENTIALS_ID = "kubeconfig-do-credentials"; break
                        case "gcp":
                        case "multi":
                            env.KUBECONFIG_CREDENTIALS_ID = ""; break   // GKE uses SA JSON, not kubeconfig file
                        default:
                            env.KUBECONFIG_CREDENTIALS_ID = "kubeconfig-credentials"
                    }

                    // Per-environment GCP defaults (can be overridden via params).
                    if (env.CLOUD_TARGET in ['gcp', 'multi']) {
                        env.RESOLVED_GCP_PROJECT      = (params.GCP_PROJECT?.trim())      ?: "YOUR_GCP_PROJECT"
                        env.RESOLVED_GKE_CLUSTER_NAME = (params.GKE_CLUSTER_NAME?.trim()) ?: "circleguard-${env.DEPLOY_ENV ?: 'stage'}"
                        env.RESOLVED_GKE_LOCATION     = (params.GKE_CLUSTER_LOCATION?.trim()) ?: "us-central1"
                        echo "GCP target => project=${env.RESOLVED_GCP_PROJECT} cluster=${env.RESOLVED_GKE_CLUSTER_NAME} location=${env.RESOLVED_GKE_LOCATION}"
                    }

                    if (env.CLOUD_TARGET == 'multi') {
                        echo "MULTI-CLOUD mode: run this pipeline twice — once with CLOUD_TARGET=digitalocean and once with CLOUD_TARGET=gcp."
                        echo "See docs/MULTICLOUD_GCP_DO.md for the staged rollout strategy."
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Compute Version") {
            steps {
                script {
                    env.RELEASE_VERSION = sh(
                        script: "scripts/ci/semver-from-git.sh",
                        returnStdout: true
                    ).trim()
                    def gitSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.GIT_SHA = gitSha

                    // Append version + SHA to image tags so every push is traceable.
                    if (env.IMAGE_TAGS) {
                        env.IMAGE_TAGS = "${env.IMAGE_TAGS},${env.RELEASE_VERSION}"
                    }

                    sh "mkdir -p build"
                    writeFile file: "build/semver.txt", text: "${env.RELEASE_VERSION}\n"
                    echo "RELEASE_VERSION=${env.RELEASE_VERSION}  GIT_SHA=${env.GIT_SHA}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "build/semver.txt", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Prompt for teardown window (only for interactive/manual builds).
        stage("Ask Teardown Minutes") {
            when {
                expression { return env.DEPLOY_ENV?.trim() && env.PIPELINE_MODE == 'full' }
            }
            steps {
                script {
                    def raw = (params.TEARDOWN_AFTER_MINUTES ?: '0').trim()
                    if (raw == '0') {
                        def isManual = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause') as boolean
                        if (isManual) {
                            def ans = input(
                                message: "Minutes before teardown for '${env.DEPLOY_ENV}'?",
                                parameters: [string(name: 'MINUTES', defaultValue: '5')]
                            )
                            env.TEARDOWN_AFTER_MINUTES = (ans ?: '5').trim()
                        } else {
                            env.TEARDOWN_AFTER_MINUTES = '5'
                            echo "Non-interactive build: defaulting teardown to 5 minutes."
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
                sh "./gradlew test jacocoTestReport --no-daemon"
            }
            post {
                always {
                    junit testResults: "**/build/test-results/test/*.xml", allowEmptyResults: true
                    archiveArtifacts artifacts: "**/build/reports/jacoco/test/**, **/build/reports/tests/test/**", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Static Analysis (SonarQube)") {
            when {
                expression {
                    def sonarHost = (env.SONAR_HOST_URL ?: "").trim()
                    def sonarToken = (env.SONAR_TOKEN ?: "").trim()
                    return sonarHost && sonarToken
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh "./gradlew sonarqube -Dsonar.host.url=${env.SONAR_HOST_URL} -Dsonar.login=${env.SONAR_TOKEN} --no-daemon"
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Write a kubeconfig file to WORKSPACE that survives across stages.
        //   GCP/GKE : activate SA + gcloud get-credentials → write to KUBECONFIG_PATH
        //   DO/local: copy the pre-built kubeconfig credential → write to KUBECONFIG_PATH
        stage("Configure K8s Access") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
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
                    // Sanity check (--short removed in kubectl 1.28+)
                    withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                        sh "kubectl version --client"
                        sh "kubectl config current-context"
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Reuse jars from Build & Test stage (no --clean). Push all tags.
        stage("Build & Push Images") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.IMAGE_TAGS?.trim() }
            }
            steps {
                script {
                    def changed = sh(
                        script: "git diff --name-only HEAD~1..HEAD 2>/dev/null || true",
                        returnStdout: true
                    ).trim()
                    boolean needBuild = !changed || (changed =~ /(services\/|Dockerfile|build\.gradle|settings\.gradle|gradlew|mobile\/|gradle\/)/)
                    if (needBuild) {
                        withCredentials([usernamePassword(
                            credentialsId: env.DOCKER_CREDENTIALS_ID,
                            usernameVariable: 'DOCKERHUB_USERNAME',
                            passwordVariable: 'DOCKERHUB_PASSWORD'
                        )]) {
                            sh "scripts/ci/build-and-push-images.sh '${env.IMAGE_TAGS}' '${env.DOCKER_IMAGE_PREFIX}' '${DOCKERHUB_USERNAME}' '${DOCKERHUB_PASSWORD}'"
                        }
                    } else {
                        echo "No service/Dockerfile changes detected — skipping image build.\nChanged: ${changed}"
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Trivy Image Scan") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.IMAGE_TAGS?.trim() }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    script {
                        // Scan only the first (environment) tag — version tags may not exist
                        // when Build & Push Images is skipped due to no service changes.
                        def trivyTag = env.IMAGE_TAGS.split(',')[0]
                        sh "scripts/ci/run-trivy.sh '${trivyTag}' '${env.DOCKER_IMAGE_PREFIX}'"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/security/results/trivy-*.json, tests/security/results/trivy-*.txt", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Enable Flyway baseline migration only on specific app services.
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

        // ------------------------------------------------------------------ //
        stage("Deploy Monitoring") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-install-metrics-server.sh"
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

        // ------------------------------------------------------------------ //
        // Locust performance tests + metrics summary report.
        stage("Performance Tests") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    script {
                        def perfEnv = (env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh "scripts/ci/run-locust.sh ${perfEnv}"
                        }
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            sh "scripts/ci/performance-metrics.sh ${perfEnv}"
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: [
                        "tests/performance/results/locust-*.log",
                        "tests/performance/results/locust-*_stats.csv",
                        "tests/performance/results/locust-*_failures.csv",
                        "tests/performance/results/metrics/*.md",
                        "tests/performance/results/metrics/*.json"
                    ].join(", "), allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Security Scan (OWASP ZAP)") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
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
                    archiveArtifacts artifacts: "tests/security/results/zap-*.html, tests/security/results/zap-*.json, tests/security/results/zap-*.md, tests/security/results/zap-*.txt", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Chaos experiments (pod-kill, scale-zero, cpu-stress) — main only.
        stage("Chaos Experiments") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/chaos-experiments.sh stage all"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/chaos/results/*.md", allowEmptyArchive: true
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Capture cluster + pod state as evidence artifact — stage branch only.
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

        // ------------------------------------------------------------------ //
        stage("Approve Prod Deploy") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                input message: "Deploy version ${env.RELEASE_VERSION ?: 'unknown'} to PRODUCTION?"
            }
        }

        // ------------------------------------------------------------------ //
        // Teardown stage BEFORE deploying prod: the cluster (3x 4 GB = 12 GB RAM)
        // cannot run stage + prod simultaneously. Stage was used for E2E/chaos tests;
        // it is no longer needed once prod is being promoted.
        stage("Teardown Stage Before Prod") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-teardown.sh stage"
                        // Wait for stage pods to fully terminate and release RAM
                        // before scheduling prod. Pods have terminationGracePeriodSeconds=30
                        // so 90s gives them time to disappear from the node.
                        sh """
                            echo 'Waiting for stage pods to terminate (max 90s)...'
                            kubectl -n stage wait --for=delete pod --all --timeout=90s 2>/dev/null || true
                            echo 'Sleeping 30s extra to let kubelet reclaim memory...'
                            sleep 30
                        """
                    }
                }
            }
        }

        // ------------------------------------------------------------------ //
        stage("Deploy Prod") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                // Prod cold boot (fresh PVCs, Kafka init) needs more time than stage.
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}",
                         "INFRA_TIMEOUT=660s",
                         "SERVICE_TIMEOUT=600s"]) {
                    sh "scripts/ci/k8s-deploy.sh prod"
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Capture cluster + pod state as evidence artifact — main branch (prod deploy).
        stage("Prod Evidence") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                withEnv(["KUBECONFIG=${env.KUBECONFIG_PATH}"]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-stage-evidence.sh prod prod-evidence.txt"
                    }
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: "prod-evidence.txt", allowEmptyArchive: true
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
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV in ['dev', 'stage'] }
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
}
