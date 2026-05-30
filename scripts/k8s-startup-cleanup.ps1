# Run automatically after Docker Desktop restarts.
# Scales down ALL namespaces to 0 to prevent RAM saturation.
# The pipeline will scale up only what it needs when it runs.

Write-Host "Waiting for Kubernetes to be ready..." -ForegroundColor Yellow
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    $result = kubectl get nodes 2>&1
    if ($result -match "Ready") {
        $ready = $true
        break
    }
    Write-Host "  Attempt $i/30..."
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Write-Error "Kubernetes did not become ready"
    exit 1
}

Write-Host "Kubernetes ready. Scaling everything to 0..." -ForegroundColor Green

foreach ($ns in @("dev", "stage", "master", "prod")) {
    $exists = kubectl get namespace $ns 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[$ns] Scaling all deployments to 0..."
        kubectl scale deployment --all -n $ns --replicas=0 2>&1 | Out-Null
        Write-Host "[$ns] Done."
    }
}

Write-Host ""
Write-Host "All namespaces scaled to 0. Run the Jenkins pipeline to deploy." -ForegroundColor Green
