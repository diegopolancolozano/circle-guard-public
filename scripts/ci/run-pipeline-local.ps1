#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "stage", "main")]
    [string]$Branch,

    [int]$TeardownAfterMinutes = 0,

    [string]$JenkinsUrl = "http://localhost:8080/",

    [string]$JobRoot = "Circle-Guard",

    [ValidateSet("cli", "rest")]
    [string]$TriggerMethod = "cli",

    [switch]$NoWait
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "[ERR]  $Message" -ForegroundColor Red
}

function Get-BranchInput {
    $choice = Read-Host "Choose branch [dev|stage|main]"
    while ($choice -notin @("dev", "stage", "main")) {
        Write-Fail "Invalid branch. Allowed values: dev, stage, main"
        $choice = Read-Host "Choose branch [dev|stage|main]"
    }
    return $choice
}

function Get-TeardownMinutesInput {
    $inputValue = Read-Host "Teardown minutes (0 keeps infra up)"
    while ($inputValue -notmatch '^\d+$') {
        Write-Fail "Value must be a non-negative integer"
        $inputValue = Read-Host "Teardown minutes (0 keeps infra up)"
    }
    return [int]$inputValue
}

function Get-JobUrlPath([string]$Root, [string]$BranchName) {
    return "job/$Root/job/$BranchName"
}

function Invoke-JenkinsBuildCLI {
    param(
        [string]$CliPath,
        [string]$Url,
        [string]$Auth,
        [string]$Root,
        [string]$BranchName,
        [int]$Minutes,
        [switch]$WaitOutput
    )

    $jobPath = "$Root/$BranchName"
    $cliArgs = @(
        "-jar", $CliPath,
        "-s", $Url,
        "-http",
        "-auth", $Auth,
        "build", $jobPath,
        "-p", "TEARDOWN_AFTER_MINUTES=$Minutes"
    )

    if ($WaitOutput) {
        $cliArgs += @("-s", "-v")
    }

    & java @cliArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to trigger Jenkins build via CLI for $jobPath"
    }
}

function Invoke-JenkinsBuildREST {
    param(
        [string]$Url,
        [string]$User,
        [string]$Token,
        [string]$Root,
        [string]$BranchName,
        [int]$Minutes
    )

    $base = $Url.TrimEnd('/')
    $authBytes = [System.Text.Encoding]::UTF8.GetBytes("$User`:$Token")
    $authHeader = "Basic " + [System.Convert]::ToBase64String($authBytes)
    $headers = @{ Authorization = $authHeader }

    # Crumb may be required depending on Jenkins CSRF configuration
    $crumbResponse = Invoke-RestMethod -Method Get -Uri "$base/crumbIssuer/api/json" -Headers $headers -ErrorAction SilentlyContinue
    if ($crumbResponse -and $crumbResponse.crumbRequestField -and $crumbResponse.crumb) {
        $headers[$crumbResponse.crumbRequestField] = $crumbResponse.crumb
    }

    $jobUrlPath = Get-JobUrlPath -Root $Root -BranchName $BranchName
    $buildUri = "$base/$jobUrlPath/buildWithParameters"
    $body = @{ TEARDOWN_AFTER_MINUTES = "$Minutes" }

    Invoke-WebRequest -Method Post -Uri $buildUri -Headers $headers -Body $body -UseBasicParsing | Out-Null
}

if (-not $Branch) {
    $Branch = Get-BranchInput
}

if ($PSBoundParameters.ContainsKey('TeardownAfterMinutes') -eq $false) {
    $TeardownAfterMinutes = Get-TeardownMinutesInput
}

if ($TeardownAfterMinutes -lt 0) {
    throw "TeardownAfterMinutes must be >= 0"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
Set-Location $repoRoot

Write-Info "Starting Jenkins container stack..."
docker compose -f docker-compose.jenkins.yml up -d jenkins | Out-Host
Write-Ok "Jenkins container up"

Write-Info "Waiting for Jenkins HTTP endpoint..."
$ready = $false
for ($i = 1; $i -le 60; $i++) {
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri ("{0}login" -f $JenkinsUrl) -TimeoutSec 3
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    throw "Jenkins is not reachable at $JenkinsUrl"
}
Write-Ok "Jenkins reachable"

Write-Info "Checking Kubernetes connectivity..."
try {
    kubectl cluster-info | Out-Null
    Write-Ok "Kubernetes cluster reachable"
} catch {
    Write-Fail "kubectl cannot reach a cluster. Enable Kubernetes first (Docker Desktop > Settings > Kubernetes) and retry."
    throw
}

$cliPath = Join-Path $repoRoot "jenkins-cli.jar"
if (-not (Test-Path $cliPath)) {
    Write-Info "Downloading jenkins-cli.jar..."
    Invoke-WebRequest -UseBasicParsing -Uri ("{0}jnlpJars/jenkins-cli.jar" -f $JenkinsUrl) -OutFile $cliPath
}
Write-Ok "CLI jar ready at $cliPath"

if (-not $env:JENKINS_USER -or -not $env:JENKINS_API_TOKEN) {
    throw "Set JENKINS_USER and JENKINS_API_TOKEN environment variables before running this script."
}

$auth = "$($env:JENKINS_USER):$($env:JENKINS_API_TOKEN)"
$jobPath = "$JobRoot/$Branch"

Write-Info "Triggering pipeline for $jobPath with TEARDOWN_AFTER_MINUTES=$TeardownAfterMinutes (method: $TriggerMethod)"

if ($TriggerMethod -eq "rest") {
    Invoke-JenkinsBuildREST -Url $JenkinsUrl -User $env:JENKINS_USER -Token $env:JENKINS_API_TOKEN -Root $JobRoot -BranchName $Branch -Minutes $TeardownAfterMinutes
} else {
    Invoke-JenkinsBuildCLI -CliPath $cliPath -Url $JenkinsUrl -Auth $auth -Root $JobRoot -BranchName $Branch -Minutes $TeardownAfterMinutes -WaitOutput:(-not $NoWait)
}

Write-Ok "Pipeline triggered for $jobPath"
if ($NoWait) {
    Write-Info "Build was triggered without waiting."
} else {
    Write-Info "Build completed (or CLI stream ended). Check Jenkins UI for full details."
}
