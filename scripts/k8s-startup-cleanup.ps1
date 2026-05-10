# Run this once after Docker Desktop restarts to prevent cluster saturation
# It scales down heavy infra and cleans stale pods before they OOM the node

Write-Host "Waiting for Kubernetes to be ready..." -ForegroundColor Yellow
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    $result = kubectl get nodes 2>&1
    if ($result -match "Ready") {
        $ready = $true
        break
    }
    Write-Host "  Attempt $i/30 - not ready yet..."
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Write-Error "Kubernetes did not become ready in time"
    exit 1
}

Write-Host "Kubernetes is ready. Cleaning up..." -ForegroundColor Green

# Scale down heavy infra in all namespaces
foreach ($ns in @("stage", "dev", "master", "prod")) {
    $exists = kubectl get namespace $ns 2>&1
    if ($exists -notmatch "Error|NotFound") {
        Write-Host "[$ns] Scaling down neo4j and openldap..."
        kubectl scale deployment neo4j openldap -n $ns --replicas=0 2>&1 | Out-Null

        Write-Host "[$ns] Deleting Error/CrashLoop pods..."
        kubectl get pods -n $ns --no-headers 2>&1 | ForEach-Object {
            $cols = $_ -split '\s+'
            if ($cols[2] -match "Error|CrashLoop|OOMKilled") {
                kubectl delete pod $cols[0] -n $ns --grace-period=0 --force 2>&1 | Out-Null
                Write-Host "  Deleted: $($cols[0])"
            }
        }
    }
}

Write-Host "Done. Cluster is clean and ready." -ForegroundColor Green
