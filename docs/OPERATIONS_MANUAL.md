# Manual de Operaciones — CircleGuard

## Prerequisitos del operador

| Herramienta | Versión mínima |
|:---|:---|
| kubectl | 1.28+ |
| kustomize | 5+ (incluido en kubectl) |
| Docker | 24+ |
| Terraform | 1.6+ |
| Java (JDK) | 21 |
| Gradle | 8.x (wrapper incluido) |

## 1. Primer despliegue

### 1.1 Infraestructura con Terraform

**DigitalOcean (DOKS):**
```bash
cd infra/terraform-do/environments/stage
terraform init
terraform apply -var="do_token=$DIGITALOCEAN_TOKEN"
# Obtén el kubeconfig del cluster
doctl kubernetes cluster kubeconfig save circleguard-stage
```

**GCP (GKE):**
```bash
cd infra/terraform-gcp/environments/stage
terraform init
terraform apply -var="gcp_project=$GCP_PROJECT"
gcloud container clusters get-credentials circleguard-stage --region us-central1
```

### 1.2 Secrets de Docker Hub (pull secret)
```bash
cd infra/terraform
terraform init
terraform apply \
  -var="dockerhub_username=$DOCKERHUB_USER" \
  -var="dockerhub_password=$DOCKERHUB_TOKEN" \
  -var="qr_secret=$QR_SECRET"
```

### 1.3 Namespaces y aplicación base
```bash
kubectl apply -f k8s/namespaces.yaml
kubectl apply -k k8s/overlays/stage
```

### 1.4 Stack de monitoreo
```bash
scripts/ci/k8s-deploy-monitoring.sh
```

## 2. Flujo de despliegue habitual (CI/CD)

El pipeline Jenkins maneja el ciclo completo automáticamente.

| Rama | Acción automática |
|:---|:---|
| `dev` | Build + tests + deploy a `dev` |
| `stage` | Build + tests + deploy a `stage` + evidencia |
| `main` | Deploy a `stage` → E2E + performance → Aprobación manual → Deploy a `prod` → Release Notes |

Para disparar manualmente con el pipeline completo:
```
Jenkins → CircleGuard → Build with Parameters
  PIPELINE_MODE = full
  CLOUD_TARGET  = digitalocean | gcp | local
  TEARDOWN_AFTER_MINUTES = 0  (para no apagar el entorno)
```

## 3. Verificar estado del despliegue

```bash
# Ver todos los pods en stage
kubectl get pods -n stage

# Ver el estado de los rollouts
kubectl rollout status deployment -n stage

# Ver logs de un servicio específico
kubectl logs -n stage -l app=circleguard-auth-service --tail=100

# Ver eventos recientes (útil para diagnosticar fallas)
kubectl get events -n stage --sort-by='.lastTimestamp' | tail -20
```

## 4. Acceso al stack de monitoreo (demo / troubleshooting)

```bash
# Abre todos los port-forwards de monitoreo en una sola terminal
scripts/ci/port-forward-monitoring.sh
```

| Dashboard | URL | Credenciales |
|:---|:---|:---|
| Grafana | http://localhost:3000 | admin / circleguard |
| Prometheus | http://localhost:9090 | — |
| Jaeger | http://localhost:16686 | — |

**Dashboard principal:** Grafana → CircleGuard → *CircleGuard Services*

## 5. Acceso a servicios de la aplicación (debug local)

```bash
kubectl -n stage port-forward svc/circleguard-auth-service    18080:8080
kubectl -n stage port-forward svc/circleguard-identity-service 18081:8080
kubectl -n stage port-forward svc/circleguard-gateway-service  18083:8080
```

Ejemplo de login:
```bash
curl -X POST http://localhost:18080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin"}'
```

## 6. Rollback de un despliegue

```bash
# Listar el historial de revisions
kubectl rollout history deployment/circleguard-auth-service -n stage

# Revertir al último estado estable
kubectl rollout undo deployment/circleguard-auth-service -n stage

# Revertir a una revisión específica
kubectl rollout undo deployment/circleguard-auth-service -n stage --to-revision=2
```

Para hacer rollback completo de todos los servicios:
```bash
for svc in auth identity promotion gateway dashboard file; do
  kubectl rollout undo deployment/circleguard-${svc}-service -n stage
done
```

## 7. Escalar y apagar entornos

```bash
# Apagar entorno stage (libera recursos, preserva namespace y secrets)
scripts/ci/k8s-teardown.sh stage

# Volver a levantar
kubectl apply -k k8s/overlays/stage
```

## 8. Ejecutar pruebas manualmente

### Pruebas unitarias e integración
```bash
./gradlew clean test jacocoTestReport
# Reportes en: services/*/build/reports/jacoco/test/html/index.html
```

### Pruebas E2E (requiere cluster con stage desplegado)
```bash
scripts/ci/run-e2e-tests.sh stage
```

### Pruebas de performance (Locust)
```bash
# Variables opcionales:
export USERS=20 SPAWN_RATE=4 RUN_TIME=60s LOAD_TEST_USER=testuser LOAD_TEST_PASS=password
scripts/ci/run-locust.sh stage
# Resultados en: tests/performance/results/
```

### Escaneo de seguridad
```bash
# Imágenes con Trivy
scripts/ci/run-trivy.sh stage diegopolancolozano/circleguard

# OWASP ZAP baseline sobre gateway
scripts/ci/run-owasp-zap.sh stage
# Reportes en: tests/security/results/
```

## 9. Gestión de secretos

Los secretos sensibles nunca van al repositorio. Se gestionan así:

| Secreto | Dónde se configura |
|:---|:---|
| `QR_SECRET` | Jenkins credential `qr-secret-value` → K8s Secret `qr-secret` |
| Docker Hub credentials | Jenkins credential `dockerhub-credentials` |
| Kubeconfig | Jenkins credential `kubeconfig-credentials` (o `kubeconfig-do-credentials`, `kubeconfig-gcp-credentials`) |
| DB / Neo4j passwords | K8s Secret `app-config` (generado por Terraform o manualmente) |

Para rotar el QR_SECRET:
```bash
kubectl -n stage create secret generic qr-secret \
  --from-literal=qr_secret="NUEVA_CLAVE" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/circleguard-auth-service   -n stage
kubectl rollout restart deployment/circleguard-gateway-service -n stage
```

## 10. Análisis de costos de infraestructura

| Recurso | Proveedor | Costo estimado/mes |
|:---|:---|:---|
| DOKS cluster (3×s-2vcpu-4gb) | DigitalOcean | ~$72 USD |
| GKE cluster (3×e2-standard-2) | GCP | ~$120 USD |
| Docker Hub (5 repos privados) | Docker Hub | $0 (plan free) |
| GCS bucket (tfstate) | GCP | <$1 USD |

Para **minimizar costos en demo**, usar `k8s-teardown.sh` después de cada sesión.
El pipeline tiene `TEARDOWN_AFTER_MINUTES` para automatizar el apagado.
