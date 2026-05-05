# GCP Terraform Setup (VMs + Jenkins Runner)

This guide provisions GCP machines end-to-end with Terraform.

## What is provisioned

- Custom VPC + subnet
- Firewall rules for SSH and Jenkins UI
- Static public IPs
- 2 Compute Engine VMs by default:
  - `circleguard-jenkins`
  - `circleguard-runner`
- Startup automation:
  - Jenkins VM installs Docker, kubectl, and Jenkins
  - Runner VM installs Docker and kubectl

Terraform root: `infra/terraform-gcp`

## 1) Authenticate in GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <TU_PROJECT_ID>
```

The identity used by Terraform must be able to enable project APIs. If your user cannot do that, enable these APIs once from the GCP console before running Terraform:

- Compute Engine API (`compute.googleapis.com`)
- IAM API (`iam.googleapis.com`)
- Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)
- Service Usage API (`serviceusage.googleapis.com`)

## 2) Prepare tfvars

```bash
cd infra/terraform-gcp
cp terraform.tfvars.example terraform.tfvars
```

Generate SSH key if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/circleguard_gcp
cat ~/.ssh/circleguard_gcp.pub
```

Put the public key into `terraform.tfvars` as `ssh_public_key`.

## 3) Plan and apply

```bash
terraform init
terraform plan
terraform apply
```

## 4) Use outputs

```bash
terraform output vm_public_ips
terraform output ssh_commands
terraform output jenkins_url
```

Open Jenkins URL from output `jenkins_url`.

## 5) Retrieve Jenkins initial admin password

```bash
ssh deployer@<JENKINS_VM_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 6) Destroy infrastructure

```bash
terraform destroy
```

## Notes

- Restrict `allowed_ssh_cidrs` to your public IP `/32` in production.
- Default machine types can be changed in `terraform.tfvars`.
- This stack provisions VMs; application deployment is still executed by Jenkins pipeline.
- If Terraform cannot enable project services, pre-enable the APIs above and rerun `terraform apply`.
