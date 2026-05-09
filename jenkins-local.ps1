#!/usr/bin/env pwsh
# jenkins-local.ps1 - Script auxiliar para Jenkins en Windows PowerShell

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerComposeFile = Join-Path $ScriptDir "docker-compose.jenkins.yml"

# Funciones auxiliares
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Yellow
}

# Funciones principales
function Invoke-Build {
    Write-Header "Construyendo imagen de Jenkins"
    docker-compose -f $DockerComposeFile build
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Imagen construida"
    }
}

function Invoke-Start {
    Invoke-Build
    Write-Header "Iniciando Jenkins"
    docker-compose -f $DockerComposeFile up -d
    
    Write-Success "Jenkins iniciado"
    Write-Info "Esperando a que Jenkins esté listo..."
    Start-Sleep -Seconds 10
    
    Write-Header "Información de Jenkins"
    Write-Host "URL: http://localhost:8080" -ForegroundColor White
    Write-Host ""
    Write-Host "Contraseña inicial (busca 'initialAdminPassword'):" -ForegroundColor White
    docker-compose -f $DockerComposeFile logs jenkins 2>$null | Select-String "initialAdminPassword"
}

function Invoke-Stop {
    Write-Header "Deteniendo Jenkins"
    docker-compose -f $DockerComposeFile down
    Write-Success "Jenkins detenido"
}

function Invoke-Restart {
    Write-Header "Reiniciando Jenkins"
    docker-compose -f $DockerComposeFile restart jenkins
    Write-Success "Jenkins reiniciado"
    Start-Sleep -Seconds 5
    Write-Host "Jenkins estará disponible en: http://localhost:8080" -ForegroundColor White
}

function Invoke-Logs {
    Write-Header "Mostrando logs de Jenkins"
    docker-compose -f $DockerComposeFile logs -f jenkins
}

function Invoke-Status {
    Write-Header "Estado de Jenkins"
    docker-compose -f $DockerComposeFile ps
}

function Invoke-TestDocker {
    Write-Header "Testeando acceso a Docker"
    docker-compose -f $DockerComposeFile exec -u jenkins jenkins docker ps >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker accessible desde Jenkins"
    } else {
        Write-Error-Custom "Docker no es accessible desde Jenkins"
        exit 1
    }
}

function Invoke-TestKubectl {
    Write-Header "Testeando acceso a Kubernetes"
    docker-compose -f $DockerComposeFile exec -u jenkins jenkins kubectl cluster-info >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Kubernetes accessible desde Jenkins"
    } else {
        Write-Error-Custom "Kubernetes no es accesible desde Jenkins"
        exit 1
    }
}

function Invoke-TestAll {
    Write-Header "Ejecutando todos los tests"
    Invoke-TestDocker
    Invoke-TestKubectl
    Write-Success "Todos los tests pasaron"
}

function Invoke-DockerLogin {
    Write-Header "Configurando Docker login en Jenkins"
    docker-compose -f $DockerComposeFile exec -u jenkins jenkins docker login
    Write-Success "Docker login configurado"
}

function Invoke-Clean {
    Write-Header "Limpiando datos de Jenkins"
    Write-Info "Esto eliminará todos los trabajos y configuración"
    $confirm = Read-Host "¿Estás seguro? (s/n)"
    
    if ($confirm -eq "s" -or $confirm -eq "S") {
        docker-compose -f $DockerComposeFile down -v
        Write-Success "Datos eliminados"
    } else {
        Write-Info "Operación cancelada"
    }
}

function Show-Usage {
    Write-Host ""
    Write-Host "Uso: $($MyInvocation.MyCommand.Name) <comando>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Comandos:" -ForegroundColor Cyan
    Write-Host "  build               - Construir imagen de Jenkins"
    Write-Host "  start               - Iniciar Jenkins"
    Write-Host "  stop                - Detener Jenkins"
    Write-Host "  restart             - Reiniciar Jenkins"
    Write-Host "  logs                - Ver logs en tiempo real"
    Write-Host "  status              - Ver estado de contenedores"
    Write-Host "  test-docker         - Verificar acceso a Docker"
    Write-Host "  test-kubectl        - Verificar acceso a Kubernetes"
    Write-Host "  test-all            - Ejecutar todos los tests"
    Write-Host "  docker-login        - Configurar Docker login"
    Write-Host "  clean               - Limpiar todos los datos (DESTRUCTIVO)"
    Write-Host "  help                - Mostrar esta ayuda"
    Write-Host ""
    Write-Host "Ejemplos:" -ForegroundColor Cyan
    Write-Host "  .\$($MyInvocation.MyCommand.Name) start"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) logs"
    Write-Host ""
}

# Router principal
switch ($Command.ToLower()) {
    "build" {
        Invoke-Build
    }
    "start" {
        Invoke-Start
    }
    "stop" {
        Invoke-Stop
    }
    "restart" {
        Invoke-Restart
    }
    "logs" {
        Invoke-Logs
    }
    "status" {
        Invoke-Status
    }
    "test-docker" {
        Invoke-TestDocker
    }
    "test-kubectl" {
        Invoke-TestKubectl
    }
    "test-all" {
        Invoke-TestAll
    }
    "docker-login" {
        Invoke-DockerLogin
    }
    "clean" {
        Invoke-Clean
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error-Custom "Comando desconocido: $Command"
        Show-Usage
        exit 1
    }
}
