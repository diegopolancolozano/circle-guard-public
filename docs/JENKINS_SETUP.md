# Jenkins Setup for CircleGuard

This repository is prepared to run from Jenkins on a VM with Docker and Kubernetes access.

## Selected microservices

This Jenkins flow is focused on these six services:

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-gateway-service`
- `circleguard-form-service`
- `circleguard-notification-service`

## Required Jenkins plugins

- Pipeline
- Git
- Credentials Binding
- Workspace Cleanup
- JUnit

## Required Jenkins credentials

Create these credentials in Jenkins:

| ID | Type | Purpose |
|:---|:---|:---|
| `dockerhub-credentials` | Username with password | Push Docker images to Docker Hub |
| `kubeconfig-credentials` | Secret file | Access the Minikube/Kubernetes cluster |
| `qr-secret-value` | Secret text | Value for Kubernetes `qr-secret` used by gateway/auth |

## VM prerequisites

Install the following on the Jenkins VM:

- Docker Engine
- Docker Compose plugin (`docker compose`)
- `kubectl`
- `minikube` if the pipeline will target the local cluster on the same VM

## Pipeline behavior

The declarative pipeline in [Jenkinsfile](../Jenkinsfile) expects:

- Docker Hub credentials for the `Build & Push Images` stage
- kubeconfig file credentials for the Kubernetes deployment and validation stages
- Docker Hub + kubeconfig + QR secret credentials for the `Terraform Bootstrap K8s` stage
- a Kubernetes cluster with namespaces `dev`, `stage`, and `prod`

## Suggested job configuration

Use a Multibranch Pipeline job:

1. Point it to this Git repository.
2. Ensure Jenkins can read the `Jenkinsfile` from the repo root.
3. Set the agent label to a node that has Docker and `kubectl` installed.
4. Enable automatic indexing if you want `dev`, `stage`, and `main` branches to run independently.

## What each branch does

- `dev`: runs Terraform bootstrap, builds the six selected services, and deploys to the `dev` namespace.
- `stage`: runs Terraform bootstrap, builds the six selected services, deploys to `stage`, runs smoke tests, and archives `stage-evidence.txt`.
- `main`: runs Terraform bootstrap, builds the six selected services, validates `stage`, runs E2E and Locust, deploys to `prod`, and generates release notes.

For a copy-paste checklist, see [docs/JENKINS_CHECKLIST.md](JENKINS_CHECKLIST.md).
