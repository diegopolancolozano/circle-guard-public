#!/bin/bash
# jenkins-local.sh - Script auxiliar para manejo de Jenkins local

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.jenkins.yml"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

function build() {
    print_header "Construyendo imagen de Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" build
    print_success "Imagen construida"
}

function start() {
    print_header "Iniciando Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    print_success "Jenkins iniciado"
    echo ""
    print_info "Esperando a que Jenkins esté listo..."
    sleep 10
    
    echo ""
    print_header "Información de Jenkins"
    echo "URL: http://localhost:8080"
    echo ""
    echo "Contraseña inicial:"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs jenkins 2>/dev/null | grep "initialAdminPassword" | tail -1 || echo "Revisar logs para obtener contraseña"
}

function stop() {
    print_header "Deteniendo Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    print_success "Jenkins detenido"
}

function restart() {
    print_header "Reiniciando Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" restart jenkins
    print_success "Jenkins reiniciado"
    sleep 5
    echo "Jenkins estará disponible en: http://localhost:8080"
}

function logs() {
    print_header "Mostrando logs de Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f jenkins
}

function exec_cmd() {
    # Ejecutar comando dentro del contenedor Jenkins
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -u jenkins jenkins "$@"
}

function test_docker() {
    print_header "Testeando acceso a Docker"
    exec_cmd docker ps > /dev/null
    print_success "Docker accessible desde Jenkins"
}

function test_kubectl() {
    print_header "Testeando acceso a Kubernetes"
    exec_cmd kubectl cluster-info > /dev/null
    print_success "Kubernetes accessible desde Jenkins"
}

function test_all() {
    print_header "Ejecutando todos los tests"
    test_docker
    test_kubectl
    print_success "Todos los tests pasaron"
}

function docker_login() {
    print_header "Configurando Docker login en Jenkins"
    exec_cmd docker login
    print_success "Docker login configurado"
}

function status() {
    print_header "Estado de Jenkins"
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps
}

function clean() {
    print_header "Limpiando datos de Jenkins"
    print_info "Esto eliminará todos los trabajos y configuración"
    read -p "¿Estás seguro? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        docker-compose -f "$DOCKER_COMPOSE_FILE" down -v
        print_success "Datos eliminados"
    else
        print_info "Operación cancelada"
    fi
}

function usage() {
    cat << EOF
Uso: $0 <comando>

Comandos:
  build               - Construir imagen de Jenkins
  start               - Iniciar Jenkins
  stop                - Detener Jenkins
  restart             - Reiniciar Jenkins
  logs                - Ver logs en tiempo real
  status              - Ver estado de contenedores
  test-docker         - Verificar acceso a Docker
  test-kubectl        - Verificar acceso a Kubernetes
  test-all            - Ejecutar todos los tests
  docker-login        - Configurar Docker login
  clean               - Limpiar todos los datos (DESTRUCTIVO)
  exec <cmd>          - Ejecutar comando en Jenkins
  help                - Mostrar esta ayuda

Ejemplos:
  $0 start
  $0 logs
  $0 exec kubectl get pods -n stage
  $0 test-all

EOF
}

# Main
case "${1:-help}" in
    build)
        build
        ;;
    start)
        build
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    status)
        status
        ;;
    test-docker)
        test_docker
        ;;
    test-kubectl)
        test_kubectl
        ;;
    test-all)
        test_all
        ;;
    docker-login)
        docker_login
        ;;
    clean)
        clean
        ;;
    exec)
        shift
        exec_cmd "$@"
        ;;
    help)
        usage
        ;;
    *)
        print_error "Comando desconocido: $1"
        echo ""
        usage
        exit 1
        ;;
esac
