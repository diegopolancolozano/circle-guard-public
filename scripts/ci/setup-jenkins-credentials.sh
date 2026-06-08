#!/usr/bin/env bash
# =============================================================================
# setup-jenkins-credentials.sh
#
# Crea/actualiza todas las credenciales requeridas por el Jenkinsfile de
# CircleGuard en la instancia Jenkins de DigitalOcean.
#
# Uso (desde la raíz del repo):
#   bash scripts/ci/setup-jenkins-credentials.sh
#   (el script carga .env automáticamente)
#
# Requiere: curl, python
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Cargar .env automáticamente ───────────────────────────────────────────────
ENV_FILE="${REPO_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
  set -a                        # exportar todo lo que se asigne
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  echo "[env] Variables cargadas desde $ENV_FILE"
else
  echo "[env] .env no encontrado — usando variables del entorno actual"
fi

# Expandir ~ en GCP_SA_FILE si viene del .env
GCP_SA_FILE="${GCP_SA_FILE:-}"
GCP_SA_FILE="${GCP_SA_FILE/#\~/$HOME}"

JENKINS_URL="${JENKINS_URL:-http://104.248.109.57:8080}"
JENKINS_USER="${JENKINS_USER:-diegoadmin}"
JENKINS_TOKEN="${JENKINS_TOKEN:-}"
JENKINS_PASS="${JENKINS_PASS:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Resolver autenticación Jenkins ───────────────────────────────────────────
if [ -z "$JENKINS_TOKEN" ] && [ -z "$JENKINS_PASS" ]; then
  warn "Ni JENKINS_TOKEN ni JENKINS_PASS definidos."
  echo  "Exporta el API token de Jenkins antes de ejecutar:"
  echo  "  export JENKINS_TOKEN=tu_api_token"
  echo  "  (Jenkins → Tu usuario → Configure → API Token → Add new Token)"
  exit 1
fi

AUTH="${JENKINS_USER}:${JENKINS_TOKEN:-$JENKINS_PASS}"
CRUMB_URL="${JENKINS_URL}/crumbIssuer/api/json"
CREDS_URL="${JENKINS_URL}/credentials/store/system/domain/_"

# Obtener crumb CSRF
CRUMB_JSON=$(curl -fsS -u "$AUTH" "$CRUMB_URL")
CRUMB_FIELD=$(echo "$CRUMB_JSON" | python -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField'])")
CRUMB_VALUE=$(echo "$CRUMB_JSON" | python -c "import sys,json; d=json.load(sys.stdin); print(d['crumb'])")
CRUMB_HEADER="${CRUMB_FIELD}:${CRUMB_VALUE}"
ok "CSRF crumb obtenido"

# ── Función genérica para crear/actualizar credencial ────────────────────────
upsert_credential() {
  local cred_id="$1"
  local xml_body="$2"

  # Intentar crear; si ya existe (409), actualizar
  HTTP_STATUS=$(curl -fsS -o /dev/null -w "%{http_code}" \
    -u "$AUTH" -H "$CRUMB_HEADER" \
    -H "Content-Type: application/xml" \
    -d "$xml_body" \
    "${CREDS_URL}/createCredentials" 2>/dev/null || echo "000")

  if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    ok "Credencial '$cred_id' creada"
  else
    # Actualizar (PUT)
    HTTP_UPDATE=$(curl -fsS -o /dev/null -w "%{http_code}" \
      -X POST \
      -u "$AUTH" -H "$CRUMB_HEADER" \
      -H "Content-Type: application/xml" \
      -d "$xml_body" \
      "${CREDS_URL}/credential/${cred_id}/config.xml" 2>/dev/null || echo "000")
    if [ "$HTTP_UPDATE" = "200" ] || [ "$HTTP_UPDATE" = "302" ]; then
      ok "Credencial '$cred_id' actualizada"
    else
      warn "No se pudo crear/actualizar '$cred_id' (HTTP create=$HTTP_STATUS update=$HTTP_UPDATE)"
    fi
  fi
}

# ── Validar variables requeridas ─────────────────────────────────────────────
MISSING=""
[ -z "${DOCKERHUB_USERNAME:-}" ] && MISSING="$MISSING DOCKERHUB_USERNAME"
[ -z "${DOCKERHUB_PASSWORD:-}" ] && MISSING="$MISSING DOCKERHUB_PASSWORD"
[ -z "${QR_SECRET:-}" ]          && MISSING="$MISSING QR_SECRET"
if [ -n "$MISSING" ]; then
  err "Variables faltantes en .env:$MISSING"
  exit 1
fi

# ── 1. dockerhub-credentials (Username/Password) ─────────────────────────────
echo ""
echo "=== dockerhub-credentials ==="
upsert_credential "dockerhub-credentials" "$(cat <<XML
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>dockerhub-credentials</id>
  <description>Docker Hub — ${DOCKERHUB_USERNAME}</description>
  <username>${DOCKERHUB_USERNAME}</username>
  <password>${DOCKERHUB_PASSWORD}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
XML
)"

# ── 2. qr-secret-value (Secret Text) ─────────────────────────────────────────
echo ""
echo "=== qr-secret-value ==="
upsert_credential "qr-secret-value" "$(cat <<XML
<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>qr-secret-value</id>
  <description>QR Secret para CircleGuard</description>
  <secret>${QR_SECRET}</secret>
</org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
XML
)"

# ── 3. gcp-sa-credentials (Secret File) ──────────────────────────────────────
echo ""
echo "=== gcp-sa-credentials ==="
if [ ! -f "$GCP_SA_FILE" ]; then
  warn "gcp-sa-credentials: archivo SA no encontrado en '$GCP_SA_FILE'"
  warn "Sube el archivo manualmente en Jenkins:"
  warn "  Jenkins → Manage Credentials → Add → Secret file → ID: gcp-sa-credentials"
else
  HTTP_SA=$(curl -fsS -o /dev/null -w "%{http_code}" \
    -u "$AUTH" -H "$CRUMB_HEADER" \
    -F "fileName=circleguard-sa.json" \
    -F "json={\"\":\"0\",\"credentials\":{\"scope\":\"GLOBAL\",\"id\":\"gcp-sa-credentials\",\"description\":\"GCP Service Account JSON\",\"file\":\"file0\",\"\$class\":\"org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl\"}}" \
    -F "file0=@${GCP_SA_FILE};type=application/json" \
    "${CREDS_URL}/createCredentials" 2>/dev/null || echo "000")
  if [ "$HTTP_SA" = "200" ] || [ "$HTTP_SA" = "302" ]; then
    ok "gcp-sa-credentials subido desde $GCP_SA_FILE"
  else
    warn "gcp-sa-credentials: HTTP $HTTP_SA — intenta subir manualmente si falla"
    warn "  Archivo: $GCP_SA_FILE"
    warn "  Jenkins → Manage Credentials → Add → Secret file → ID: gcp-sa-credentials"
  fi
fi

# ── 4. kubeconfig-do-credentials (Secret File) ───────────────────────────────
echo ""
echo "=== kubeconfig-do-credentials ==="
KUBECONFIG_DO="${KUBECONFIG_DO_FILE:-$HOME/.kube/do-kubeconfig.yaml}"

if [ ! -f "$KUBECONFIG_DO" ]; then
  warn "kubeconfig-do-credentials: kubeconfig DO no encontrado en '$KUBECONFIG_DO'"
  echo ""
  echo "  Para generarlo, corre en tu máquina local:"
  echo "    doctl kubernetes cluster kubeconfig show circleguard-cluster > ~/.kube/do-kubeconfig.yaml"
  echo "  Luego:"
  echo "    export KUBECONFIG_DO_FILE=~/.kube/do-kubeconfig.yaml"
  echo "    bash scripts/ci/setup-jenkins-credentials.sh"
else
  HTTP_KC=$(curl -fsS -o /dev/null -w "%{http_code}" \
    -u "$AUTH" -H "$CRUMB_HEADER" \
    -F "fileName=do-kubeconfig.yaml" \
    -F "json={\"\":\"0\",\"credentials\":{\"scope\":\"GLOBAL\",\"id\":\"kubeconfig-do-credentials\",\"description\":\"DOKS kubeconfig — circleguard-cluster\",\"file\":\"file0\",\"\$class\":\"org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl\"}}" \
    -F "file0=@${KUBECONFIG_DO};type=application/yaml" \
    "${CREDS_URL}/createCredentials" 2>/dev/null || echo "000")
  if [ "$HTTP_KC" = "200" ] || [ "$HTTP_KC" = "302" ]; then
    ok "kubeconfig-do-credentials subido desde $KUBECONFIG_DO"
  else
    warn "kubeconfig-do-credentials: HTTP $HTTP_KC — intenta subir manualmente si falla"
    warn "  Archivo: $KUBECONFIG_DO"
  fi
fi

# ── Verificación final ────────────────────────────────────────────────────────
echo ""
echo "=== Credenciales configuradas en Jenkins ==="
curl -fsS -u "$AUTH" "${CREDS_URL}/api/json?tree=credentials[id,description]" \
  | python -c "
import sys, json
data = json.load(sys.stdin)
creds = data.get('credentials', [])
required = {'dockerhub-credentials', 'gcp-sa-credentials', 'kubeconfig-do-credentials', 'qr-secret-value'}
found = set()
for c in creds:
    cid = c.get('id','')
    marker = '✅' if cid in required else '  '
    print(f'  {marker} {cid}: {c.get(\"description\",\"\")}')
    found.add(cid)
missing = required - found
if missing:
    print()
    print(f'  ⚠️  Faltan: {missing}')
else:
    print()
    print('  ✅ Todas las credenciales requeridas están presentes')
" 2>/dev/null || warn "No se pudo listar credenciales (verifica usuario/token)"
