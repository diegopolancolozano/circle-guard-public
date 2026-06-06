#!/usr/bin/env bash
# =============================================================================
# setup-jenkins-tools.sh
#
# Instala y verifica todas las herramientas requeridas por el Jenkinsfile de
# CircleGuard dentro del contenedor Jenkins corriendo en DigitalOcean.
#
# Herramientas auditadas:
#   git, java, docker, kubectl, gcloud, gke-gcloud-auth-plugin,
#   trivy, curl, nohup, awk, base64
#
# Cómo usar (desde tu máquina local):
#   ssh root@104.248.109.57 "bash -s" < scripts/ci/setup-jenkins-tools.sh
#
# O copiando el script al servidor primero:
#   scp scripts/ci/setup-jenkins-tools.sh root@104.248.109.57:/tmp/
#   ssh root@104.248.109.57 "bash /tmp/setup-jenkins-tools.sh"
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()      { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# ── Detectar contenedor Jenkins ──────────────────────────────────────────────
section "1/6 Detectando contenedor Jenkins"
CONTAINER=$(docker ps --format "{{.Names}}" | grep -i jenkins | head -1 || true)
if [ -z "$CONTAINER" ]; then
  err "No se encontró contenedor Jenkins corriendo."
  echo "Contenedores activos:"
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
  exit 1
fi
ok "Contenedor: $CONTAINER"
docker inspect "$CONTAINER" --format "  Image: {{.Config.Image}} | Status: {{.State.Status}}"

# ── gcloud + gke-gcloud-auth-plugin ──────────────────────────────────────────
section "2/6 gcloud + gke-gcloud-auth-plugin"
docker exec -u root "$CONTAINER" bash -c '
set -euo pipefail

if command -v gcloud &>/dev/null; then
  echo "[OK] gcloud ya instalado: $(gcloud version 2>/dev/null | head -1)"
else
  echo "Instalando Google Cloud CLI..."
  apt-get update -qq
  apt-get install -y -qq apt-transport-https ca-certificates gnupg curl

  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" \
    | tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null

  apt-get update -qq
  apt-get install -y -qq google-cloud-cli
  echo "[OK] gcloud instalado: $(gcloud version | head -1)"
fi

if command -v gke-gcloud-auth-plugin &>/dev/null; then
  echo "[OK] gke-gcloud-auth-plugin ya instalado"
else
  echo "Instalando gke-gcloud-auth-plugin..."
  apt-get install -y -qq google-cloud-sdk-gke-gcloud-auth-plugin
  echo "[OK] gke-gcloud-auth-plugin instalado"
fi
'

# ── Trivy ─────────────────────────────────────────────────────────────────────
section "3/6 Trivy (escaneo de vulnerabilidades)"
docker exec -u root "$CONTAINER" bash -c '
set -euo pipefail

if command -v trivy &>/dev/null; then
  echo "[OK] trivy ya instalado: $(trivy --version 2>/dev/null | head -1)"
else
  echo "Instalando Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin v0.52.2
  echo "[OK] trivy instalado: $(trivy --version | head -1)"
fi
'

# ── curl (requerido por smoke tests y notify-webhook) ─────────────────────────
section "4/6 curl"
docker exec -u root "$CONTAINER" bash -c '
if command -v curl &>/dev/null; then
  echo "[OK] curl ya instalado: $(curl --version | head -1)"
else
  echo "Instalando curl..."
  apt-get update -qq && apt-get install -y -qq curl
  echo "[OK] curl instalado: $(curl --version | head -1)"
fi
'

# ── Permisos Docker socket ────────────────────────────────────────────────────
section "5/6 Permisos Docker socket para usuario jenkins"

# GID del socket en el HOST
SOCK_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")
echo "GID del socket /var/run/docker.sock en host: ${SOCK_GID:-desconocido}"

if [ -n "$SOCK_GID" ]; then
  docker exec -u root "$CONTAINER" bash -c "
set -euo pipefail

# Crear grupo con ese GID si no existe, o reutilizar el existente
EXISTING_GROUP=\$(getent group ${SOCK_GID} | cut -d: -f1 || echo '')
if [ -z \"\$EXISTING_GROUP\" ]; then
  groupadd -g ${SOCK_GID} docker-socket
  EXISTING_GROUP=docker-socket
  echo 'Grupo docker-socket creado con GID=${SOCK_GID}'
else
  echo \"Grupo existente con GID=${SOCK_GID}: \$EXISTING_GROUP\"
fi

# Agregar jenkins al grupo
if id jenkins &>/dev/null; then
  usermod -aG \"\$EXISTING_GROUP\" jenkins
  echo \"[OK] jenkins agregado al grupo \$EXISTING_GROUP\"
else
  echo '[WARN] usuario jenkins no encontrado en el contenedor'
fi
"
fi

# Verificar que el socket tiene permisos de grupo correctos
docker exec -u root "$CONTAINER" bash -c '
ls -la /var/run/docker.sock 2>/dev/null || echo "[WARN] socket no visible dentro del contenedor"
# Dar permisos de lectura/escritura al grupo en el socket
chmod 660 /var/run/docker.sock 2>/dev/null || true
'

# ── Verificación final como usuario jenkins ───────────────────────────────────
section "6/6 Verificación final como usuario jenkins"
docker exec -u jenkins "$CONTAINER" bash -c '
check() {
  local tool="$1"
  local version_cmd="${2:-$1 --version}"
  if command -v "$tool" &>/dev/null; then
    local ver; ver=$(eval "$version_cmd" 2>/dev/null | head -1 || echo "?")
    printf "  [OK]   %-28s %s\n" "$tool" "$ver"
    return 0
  else
    printf "  [MISS] %-28s NO ENCONTRADO\n" "$tool"
    return 1
  fi
}

FAILED=0

echo ""
echo "  Herramienta                    Versión"
echo "  ─────────────────────────────────────────────────────────"
check git             "git --version"                                     || FAILED=$((FAILED+1))
check java            "java -version 2>&1"                                || FAILED=$((FAILED+1))
check docker          "docker version --format \"{{.Client.Version}}\""   || FAILED=$((FAILED+1))
check kubectl         "kubectl version --client 2>/dev/null | head -1"   || FAILED=$((FAILED+1))
check gcloud          "gcloud version 2>/dev/null | head -1"             || FAILED=$((FAILED+1))
check gke-gcloud-auth-plugin "gke-gcloud-auth-plugin --version 2>/dev/null | head -1" || FAILED=$((FAILED+1))
check trivy           "trivy --version 2>/dev/null | head -1"            || FAILED=$((FAILED+1))
check curl            "curl --version | head -1"                          || FAILED=$((FAILED+1))
check nohup           "echo built-in"                                     || FAILED=$((FAILED+1))
check awk             "awk --version 2>/dev/null | head -1"              || FAILED=$((FAILED+1))
check base64          "base64 --version 2>/dev/null | head -1"           || FAILED=$((FAILED+1))
check xargs           "xargs --version 2>/dev/null | head -1"            || FAILED=$((FAILED+1))

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "  ✅ Todas las herramientas están disponibles para el usuario jenkins."
else
  echo "  ⚠️  $FAILED herramienta(s) faltantes — revisar arriba."
  exit 1
fi

echo ""
echo "  --- Docker socket ---"
if docker version --format "Server: {{.Server.Version}}" 2>/dev/null; then
  echo "  [OK] jenkins puede comunicarse con el daemon Docker"
else
  echo "  [WARN] jenkins NO puede comunicarse con Docker (socket sin permisos)"
  echo "         Solución: reiniciar el contenedor para que los grupos nuevos surtan efecto"
fi
'
