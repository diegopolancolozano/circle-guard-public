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

The CI flow is centered on these six microservices:

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-gateway-service`
- `circleguard-form-service`
- `circleguard-notification-service`

## Terraform bootstrap

Terraform files are in `infra/terraform`.
The Jenkins stage `Terraform Bootstrap K8s` uses:

- `dockerhub-credentials`
- `kubeconfig-credentials`
- `qr-secret-value`

This stage is idempotent and prepares base resources before service deployment.

### Namespace management

**Important:** Kubernetes namespaces (`dev`, `stage`, `prod`) are created by `kubectl apply -f k8s/namespaces.yaml` in the `Deploy` stage and are **not** managed by Terraform.
Terraform uses a `data` source to reference existing namespaces, avoiding conflicts when rerunning pipelines across different branches.

If you encounter "namespaces already exist" errors from Terraform, it means the namespaces were already created in a previous pipeline run.
This is normal and expected behavior—Terraform will skip namespace creation and proceed to create/update secrets and config within those namespaces.

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
- `FORM_BASE_URL`
- `QR_SECRET`

The Jenkins `main` branch flow already exports them through `scripts/ci/run-e2e-tests.sh`.

## Stage Evidence Artifact

On the `stage` branch, Jenkins now runs `scripts/ci/k8s-stage-evidence.sh stage stage-evidence.txt` and archives `stage-evidence.txt`.
This file contains:

- deployment rollout status
- pod and service inventory
- k8s-wide output useful for screenshots and report evidence

## Managing resources to save cloud costs

To free up GKE resources without permanently deleting your namespaces and configurations, use the teardown script:

### Scale down all microservices (keep namespace and configs)

```bash
./scripts/ci/k8s-teardown.sh dev
```

This scales all deployments (microservices and infrastructure) to 0 replicas, freeing compute resources while preserving:
- Kubernetes namespaces
- ConfigMaps and Secrets
- Service definitions

### Completely delete a namespace

```bash
./scripts/ci/k8s-teardown.sh dev --delete-namespace
```

This permanently deletes the entire namespace and all resources within it. Use this for cleanup.

### Bring services back online

To bring services back online after scaling down, redeploy:

```bash
./scripts/ci/k8s-deploy.sh dev
```

This reapplies the deployment manifests and scales services back to 1 replica (or configured count).
