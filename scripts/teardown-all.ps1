param(
    [Parameter(Mandatory=$true)]
    [string]$SaKeyFile
)

if (-not (Test-Path $SaKeyFile)) {
    Write-Error "Service account key not found: $SaKeyFile"
    exit 1
}

$SaKeyFile = Resolve-Path $SaKeyFile
$WorkspaceDir = Resolve-Path (Join-Path $PSScriptRoot "../..")

Write-Host "=== CircleGuard Infrastructure Teardown ===" -ForegroundColor Red
Write-Host "This will DESTROY all GCP resources (VMs, GKE cluster, VPC, IPs)."
Write-Host "Press Ctrl+C within 10 seconds to cancel..."
Start-Sleep -Seconds 10

$dockerCreds = @(
    "-e", "GOOGLE_APPLICATION_CREDENTIALS=/workspace/sa.json",
    "-v", "${SaKeyFile}:/workspace/sa.json:ro"
)

# ── 1. Destroy GKE cluster (infra/terraform) ──────────────────────────────────
Write-Host ""
Write-Host "=== [1/2] Destroying GKE cluster (infra/terraform) ===" -ForegroundColor Yellow

$tfState = Join-Path $WorkspaceDir "infra/terraform/terraform.tfstate"
$tfDir   = Join-Path $WorkspaceDir "infra/terraform"

if (Test-Path $tfState) {
    docker run --rm @dockerCreds `
        -v "${WorkspaceDir}:/workspace" `
        -w "/workspace/infra/terraform" `
        hashicorp/terraform:1.9.8 `
        init -input=false

    docker run --rm @dockerCreds `
        -v "${WorkspaceDir}:/workspace" `
        -w "/workspace/infra/terraform" `
        hashicorp/terraform:1.9.8 `
        destroy -auto-approve `
        -var "kubeconfig_path=/tmp/dummy" `
        -var "dockerhub_username=dummy" `
        -var "dockerhub_password=dummy" `
        -var "dockerhub_email=dummy@dummy.com" `
        -var "qr_secret=dummy"
} else {
    Write-Host "No terraform state found in infra/terraform, skipping."
}

# ── 2. Destroy VMs (infra/terraform-gcp) ─────────────────────────────────────
Write-Host ""
Write-Host "=== [2/2] Destroying VMs Jenkins + Runner (infra/terraform-gcp) ===" -ForegroundColor Yellow

$tfStateGcp = Join-Path $WorkspaceDir "infra/terraform-gcp/terraform.tfstate"

if (Test-Path $tfStateGcp) {
    docker run --rm @dockerCreds `
        -v "${WorkspaceDir}:/workspace" `
        -w "/workspace/infra/terraform-gcp" `
        hashicorp/terraform:1.9.8 `
        init -input=false

    docker run --rm @dockerCreds `
        -v "${WorkspaceDir}:/workspace" `
        -w "/workspace/infra/terraform-gcp" `
        hashicorp/terraform:1.9.8 `
        destroy -auto-approve
} else {
    Write-Host "No terraform state found in infra/terraform-gcp, skipping."
}

Write-Host ""
Write-Host "=== Teardown complete. All GCP resources destroyed. ===" -ForegroundColor Green
