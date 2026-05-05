# Jenkins Pipeline and VM Test Commands

This repository includes a Jenkins pipeline in [Jenkinsfile](Jenkinsfile) that runs these main stages:

1. Checkout and prepare shell scripts.
2. Bootstrap Kubernetes base resources (namespaces and required secrets) with Terraform.
3. Build and run unit tests for the backend services.
4. Build and push Docker images to Docker Hub.
5. Deploy to Kubernetes overlays for `dev`, `stage`, or `prod`.
6. Run smoke tests on `stage`.
7. Collect stage evidence from Kubernetes and archive it as a Jenkins artifact.
8. Run E2E tests and Locust performance tests for `main`.
9. Generate `release-notes.md` from Conventional Commits.

## Terraform bootstrap

Terraform files are in `infra/terraform`.
The Jenkins stage `Terraform Bootstrap K8s` uses:

- `dockerhub-credentials`
- `kubeconfig-credentials`
- `qr-secret-value`

This stage is idempotent and prepares base resources before service deployment.

## VM Docker Commands

Use these commands on the VM where the repository is checked out.

### Full test environment

```bash
docker compose -f docker-compose.test.yml up --abort-on-container-exit --remove-orphans --build

# Or use the helper script (recommended on CI/VM):
./scripts/run-tests-vm.sh
```

### Stop and clean up

```bash
docker compose -f docker-compose.test.yml down
```

### Run only the E2E module

```bash
./gradlew :tests:circleguard-e2e-tests:test --no-daemon
```

The E2E module reads these environment variables:

- `IDENTITY_BASE_URL`
- `PROMOTION_BASE_URL`
- `GATEWAY_BASE_URL`
- `FILE_BASE_URL`
- `DASHBOARD_BASE_URL`
- `QR_SECRET`

The Jenkins `main` branch flow already exports them through `scripts/ci/run-e2e-tests.sh`.

## Stage Evidence Artifact

On the `stage` branch, Jenkins now runs `scripts/ci/k8s-stage-evidence.sh stage stage-evidence.txt` and archives `stage-evidence.txt`.
This file contains:

- deployment rollout status
- pod and service inventory
- k8s-wide output useful for screenshots and report evidence
