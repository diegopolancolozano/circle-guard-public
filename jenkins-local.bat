@echo off
REM jenkins-local.bat - Script auxiliar para Jenkins en Windows

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set DOCKER_COMPOSE_FILE=%SCRIPT_DIR%docker-compose.jenkins.yml

if "%1"=="" (
    call :usage
    exit /b 1
)

goto %1%

:build
echo.
echo ========================================
echo Construyendo imagen de Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" build
echo.
echo [OK] Imagen construida
goto :eof

:start
call :build
echo.
echo ========================================
echo Iniciando Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" up -d
echo.
echo [OK] Jenkins iniciado
echo.
echo [INFO] Esperando a que Jenkins esté listo...
timeout /t 10 /nobreak
echo.
echo ========================================
echo Información de Jenkins
echo ========================================
echo URL: http://localhost:8080
echo.
echo Contraseña inicial (busca "initialAdminPassword"):
docker-compose -f "%DOCKER_COMPOSE_FILE%" logs jenkins 2>nul | find "initialAdminPassword"
goto :eof

:stop
echo.
echo ========================================
echo Deteniendo Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" down
echo.
echo [OK] Jenkins detenido
goto :eof

:restart
echo.
echo ========================================
echo Reiniciando Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" restart jenkins
echo.
echo [OK] Jenkins reiniciado
timeout /t 5 /nobreak
echo Jenkins estará disponible en: http://localhost:8080
goto :eof

:logs
echo.
echo ========================================
echo Mostrando logs de Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" logs -f jenkins
goto :eof

:status
echo.
echo ========================================
echo Estado de Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" ps
goto :eof

:test-docker
echo.
echo ========================================
echo Testeando acceso a Docker
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" exec -u jenkins jenkins docker ps >nul
if errorlevel 1 (
    echo [ERROR] Docker no es accessible desde Jenkins
    exit /b 1
)
echo [OK] Docker accesible desde Jenkins
goto :eof

:test-kubectl
echo.
echo ========================================
echo Testeando acceso a Kubernetes
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" exec -u jenkins jenkins kubectl cluster-info >nul
if errorlevel 1 (
    echo [ERROR] Kubernetes no es accesible desde Jenkins
    exit /b 1
)
echo [OK] Kubernetes accesible desde Jenkins
goto :eof

:test-all
echo.
echo ========================================
echo Ejecutando todos los tests
echo ========================================
call :test-docker
call :test-kubectl
echo.
echo [OK] Todos los tests pasaron
goto :eof

:docker-login
echo.
echo ========================================
echo Configurando Docker login en Jenkins
echo ========================================
docker-compose -f "%DOCKER_COMPOSE_FILE%" exec -u jenkins jenkins docker login
echo.
echo [OK] Docker login configurado
goto :eof

:usage
echo.
echo Uso: %0 COMANDO
echo.
echo Comandos:
echo   build               - Construir imagen de Jenkins
echo   start               - Iniciar Jenkins
echo   stop                - Detener Jenkins
echo   restart             - Reiniciar Jenkins
echo   logs                - Ver logs en tiempo real
echo   status              - Ver estado de contenedores
echo   test-docker         - Verificar acceso a Docker
echo   test-kubectl        - Verificar acceso a Kubernetes
echo   test-all            - Ejecutar todos los tests
echo   docker-login        - Configurar Docker login
echo   help                - Mostrar esta ayuda
echo.
echo Ejemplos:
echo   %0 start
echo   %0 logs
echo.
goto :eof

:help
call :usage
goto :eof

:default
echo [ERROR] Comando desconocido: %1
call :usage
exit /b 1
