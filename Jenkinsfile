pipeline {
    agent any

    parameters {
        choice(name: 'PIPELINE_MODE', choices: ['reduced', 'full'], description: 'reduced = build + integration tests only; full = deploy, performance, evidence and release flow')
        choice(name: 'CLOUD_TARGET', choices: ['local', 'digitalocean', 'gcp', 'multi'], description: 'Cloud execution target for full mode. local = kubeconfig local, digitalocean = DOKS kubeconfig, gcp = GKE kubeconfig, multi = both DO and GCP strategy')
        string(name: 'TEARDOWN_AFTER_MINUTES', defaultValue: '5', description: 'Minutes to wait before tearing down deployed environment. Use 0 to prompt manually and keep it running until teardown is scheduled.')
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

        stage("Build & Integration Tests") {
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
                    // Detect whether relevant files changed (services, Dockerfile, build files)
                    def changed = sh(script: "git diff --name-only HEAD~1..HEAD || true", returnStdout: true).trim()
                    boolean needBuild = false
                    if (!changed) {
                        // No previous commit in shallow clones or first build: build to be safe
                        needBuild = true
                    } else {
                        if (changed =~ /(services\/|Dockerfile|build.gradle|settings.gradle|gradlew|mobile\/|app\/|gradle\/)/) {
                            needBuild = true
                        }
                    }

                    if (needBuild) {
                        withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: "DOCKERHUB_USERNAME", passwordVariable: "DOCKERHUB_PASSWORD")]) {
                            sh "scripts/ci/build-and-push-images.sh '${IMAGE_TAGS}' '${DOCKER_IMAGE_PREFIX}' '${DOCKERHUB_USERNAME}' '${DOCKERHUB_PASSWORD}'"
                        }
                    } else {
                        echo "No relevant changes detected in code/images; skipping build & push. Changed files:\n${changed}"
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
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    script {
                        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                            if (env.BRANCH_NAME == 'main') {
                                echo "Setting SPRING_FLYWAY_BASELINE_ON_MIGRATE=true on 'stage' and 'prod' namespaces"
                                sh "kubectl -n stage set env deployment --all SPRING_FLYWAY_BASELINE_ON_MIGRATE=true || true"
                                sh "kubectl -n prod set env deployment --all SPRING_FLYWAY_BASELINE_ON_MIGRATE=true || true"
                            } else {
                                echo "Setting SPRING_FLYWAY_BASELINE_ON_MIGRATE=true on namespace ${env.DEPLOY_ENV}"
                                sh "kubectl -n ${env.DEPLOY_ENV} set env deployment --all SPRING_FLYWAY_BASELINE_ON_MIGRATE=true || true"
                            }
                        }
                    }
                }
            }
        }

        stage("Deploy") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV?.trim() }
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
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    script {
                        def perfEnv = (env.BRANCH_NAME == 'main') ? 'stage' : env.DEPLOY_ENV

                        def tasks = [:]

                        if (env.BRANCH_NAME == 'stage') {
                            tasks['smoke-tests'] = {
                                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                    sh "scripts/ci/k8s-smoke-tests.sh stage"
                                }
                            }
                        } else if (env.BRANCH_NAME == 'main') {
                            tasks['e2e-tests'] = {
                                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                    sh "scripts/ci/run-e2e-tests.sh stage"
                                }
                            }
                        }

                        tasks['performance'] = {
                            catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                                sh "scripts/ci/run-locust.sh ${perfEnv}"
                                sh "scripts/ci/performance-metrics.sh ${perfEnv}"
                            }
                        }

                        parallel tasks
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "tests/performance/results/locust-*.log, tests/performance/results/locust-*_stats.csv, tests/performance/results/locust-*_failures.csv, tests/performance/results/locust-*_exceptions.csv, tests/performance/results/metrics/*.md, tests/performance/results/metrics/*.json", allowEmptyArchive: true
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
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh "scripts/ci/k8s-stage-evidence.sh stage stage-evidence.txt"
                        archiveArtifacts artifacts: "stage-evidence.txt", onlyIfSuccessful: true
                    }
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
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                    sh "scripts/ci/k8s-deploy.sh prod"
                }
            }
        }

        stage("Generate Release Notes") {
            when {
                allOf {
                    branch "main"
                    expression { return env.PIPELINE_MODE == 'full' }
                }
            }
            steps {
                sh "scripts/ci/generate-release-notes.sh"
                archiveArtifacts artifacts: "release-notes.md", onlyIfSuccessful: true
            }
        }

        stage("Scheduled Teardown") {
            when {
                expression { return env.PIPELINE_MODE == 'full' && env.DEPLOY_ENV in ["dev", "stage"] }
            }
            steps {
                script {
                    def teardownRaw = (env.TEARDOWN_AFTER_MINUTES ?: "0").trim()
                    if (!(teardownRaw ==~ /^\d+$/)) {
                        error "TEARDOWN_AFTER_MINUTES must be a non-negative integer. Received: '${teardownRaw}'"
                    }

                    int teardownMinutes = teardownRaw as Integer
                    if (teardownMinutes > 0) {
                        echo "Scheduling background teardown in ${teardownMinutes} minute(s) for env '${env.DEPLOY_ENV}'"
                        // Run teardown in background so the pipeline can finish and be re-run later.
                        withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: "KUBECONFIG")]) {
                            sh "nohup sh -c 'sleep ${teardownMinutes}m && scripts/ci/k8s-teardown.sh ${env.DEPLOY_ENV}' >/dev/null 2>&1 &"
                        }
                    } else {
                        echo "TEARDOWN_AFTER_MINUTES=0, environment '${env.DEPLOY_ENV}' will remain up."
                    }
                }
            }
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
