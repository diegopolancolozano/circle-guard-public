# Jenkins Setup Checklist

Use this checklist to prepare Jenkins on the VM for CircleGuard.

## 1. Install Jenkins plugins

Before configuring Jenkins, if you still do not have GCP VMs, provision them first with Terraform:

- Follow `docs/GCP_TERRAFORM_SETUP.md`
- This creates `circleguard-jenkins` and `circleguard-runner` VMs

Install these plugins from the Jenkins plugin manager:

- Pipeline
- Git
- Credentials Binding
- Workspace Cleanup
- JUnit
- Docker Pipeline
- Kubernetes CLI (optional, if you want Jenkins-managed `kubectl` tooling)

## 2. Prepare the VM

### 2.1 Enter the VM where Docker/Jenkins runs

If Jenkins runs on a remote Linux VM (for example in GCP), connect first:

```bash
ssh <user>@<vm-ip>
```

If you are on Windows with Docker Desktop, you are already on the Docker host for CLI usage.
Optional: to inspect the Docker Desktop internal distro, you can open:

```powershell
wsl -d docker-desktop
```

### 2.2 Verify Docker/Kubernetes tools on that host

Install and verify these tools on the Jenkins node:

```bash
docker --version
docker compose version
kubectl version --client
```

If `kubectl` is not installed, install it before running the pipeline.
`minikube` is only required if the Jenkins VM itself hosts the local cluster.

If you do have Minikube on the VM, verify it with:

```bash
minikube status
```

If `minikube` is not available, continue with a valid cluster kubeconfig exported from the target cluster.

## 3. Export kubeconfig for Jenkins

If the cluster is the local Minikube instance on the same VM, export a clean kubeconfig file:

```bash
kubectl config view --raw --flatten --minify > kubeconfig-credentials.yaml
```

If you use Minikube directly, this is also valid:

```bash
minikube kubeconfig > kubeconfig-credentials.yaml
```

Then upload that file to Jenkins as a Secret file credential with ID `kubeconfig-credentials`.

If you are on Windows and do not have Minikube installed, that is fine: create the kubeconfig file from the cluster that Jenkins will use and upload it the same way.

## 4. Create Jenkins credentials

Create these credentials in Jenkins > Manage Jenkins > Credentials:

| ID | Kind | Notes |
|:---|:---|:---|
| `dockerhub-credentials` | Username with password | Docker Hub user and access token/password |
| `kubeconfig-credentials` | Secret file | Kubeconfig used by the deployment and validation stages |
| `qr-secret-value` | Secret text | Secret used to create/update Kubernetes `qr-secret` |

## 5. Create the job

Use a Multibranch Pipeline job and configure:

1. Repository URL pointing to this project.
2. Branch discovery for `dev`, `stage`, and `main`.
3. Script path set to `Jenkinsfile`.
4. An agent label that has Docker, `kubectl`, and access to the VM cluster.

## 6. Verify the branch behavior

Run each branch once and confirm the expected result:

- `dev`: terraform bootstrap + build + unit tests + deploy to `dev`
- `stage`: terraform bootstrap + build + unit tests + deploy to `stage` + smoke tests + stage evidence
- `main`: terraform bootstrap + build + unit tests + deploy to `stage` + E2E + Locust + deploy to `prod` + release notes

## 7. Archive evidence

Confirm Jenkins archives these artifacts:

- `stage-evidence.txt`
- `release-notes.md`
- test reports from `build/reports/**`
