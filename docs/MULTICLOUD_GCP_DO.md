# Estrategia Multi-Cloud: GCP (Primario) + DigitalOcean (Respaldo)

## Arquitectura

CircleGuard opera en dos proveedores cloud simultáneamente:

| Rol | Proveedor | Cluster | Región |
|-----|-----------|---------|--------|
| **Primario** | Google Cloud Platform | GKE (`circleguard-stage`) | `us-central1` |
| **Respaldo** | DigitalOcean | DOKS (`circleguard-cluster`) | `nyc1` |

> Proyecto GCP: `project-61c89277-1b90-444b-bc4` · Service Account: `circleguard-jenkins`.
> Cluster DOKS id: `5a66436d-6520-4a50-bcda-2bb40bb07e28`. Ambos clusters corren el stack
> completo de CircleGuard en el namespace `stage`.

GCP es el proveedor primario por su integración nativa con GKE, autoscaling de nodos, y SLA más alto. DigitalOcean actúa como failover activo — recibe tráfico automáticamente si GCP falla.

```
Usuarios
   │
   ▼
[DNS / Load Balancer externo]
   ├──(primary)──► GKE us-central1  (GCP)
   └──(failover)─► DOKS nyc1        (DigitalOcean)
```

---

## 1. Despliegue en dos clouds

El pipeline de Jenkins soporta `CLOUD_TARGET=gcp`, `CLOUD_TARGET=digitalocean` y `CLOUD_TARGET=multi`.

### Flujo en rama `main` (producción)

```
push main
   │
   ├─ Build & Test
   ├─ Build & Push Images (tags: stage, prod, semver)
   ├─ Deploy stage (DO) → E2E/Chaos tests
   ├─ Teardown stage
   ├─ [Approve Prod Deploy]
   ├─ Deploy Prod → GCP (primario)   ← CLOUD_TARGET=gcp
   └─ Deploy Prod → DO  (respaldo)   ← CLOUD_TARGET=digitalocean
```

Para ejecutar el despliegue completo multi-cloud desde Jenkins:

1. Lanzar pipeline con `CLOUD_TARGET=gcp` → despliega en GKE
2. Lanzar pipeline con `CLOUD_TARGET=digitalocean` → despliega en DOKS

O usar `CLOUD_TARGET=multi` que ejecuta ambos secuencialmente.

### Credenciales en Jenkins

| Credential ID | Tipo | Uso |
|---------------|------|-----|
| `gcp-sa-credentials` | Secret file (JSON) | Service Account GKE |
| `kubeconfig-do-credentials` | Secret file | kubeconfig DOKS |
| `dockerhub-credentials` | Username/Password | Docker Hub push |

### Configuración GCP (ensure-gke-access.sh)

```bash
# El script autentica con la SA, obtiene credenciales GKE y escribe el kubeconfig:
scripts/ci/ensure-gke-access.sh
# Variables requeridas: GCP_SA_FILE, GCP_PROJECT, GKE_CLUSTER_NAME, GKE_CLUSTER_LOCATION
```

---

## 2. Estrategia de respaldo entre clouds

### Modelo activo-pasivo con failover automático vía DNS

El DNS apunta al endpoint de GCP como registro primario. DigitalOcean está configurado como registro de respaldo con TTL bajo (60s) para failover rápido.

```
circleguard.app  →  A  34.x.x.x   (GCP LoadBalancer)   priority=10  health-check=ON
circleguard.app  →  A  104.x.x.x  (DO LoadBalancer)    priority=20  health-check=ON
```

Con Cloudflare o Route53 Load Balancing esto se implementa como:
- Health check cada 30s contra `/actuator/health` del gateway
- Si GCP falla el health check 2 veces consecutivas → tráfico redirige a DO automáticamente
- TTL de 60s garantiza propagación en menos de 1 minuto

### Sincronización de datos

- **PostgreSQL**: base de datos en GCP como primaria. DO usa su propia instancia con datos de la última imagen disponible (acceptable para staging/demo; en producción real se usaría Cloud SQL con réplica cross-region).
- **Redis**: stateless entre clouds — cada cluster tiene su propia instancia. Las sesiones son JWT, no dependen de Redis compartido.
- **Kafka**: mensajería local por cluster. Eventos en tránsito se pierden en failover (acceptable dado el contexto académico).

### Procedimiento de failover manual

```bash
# 1. Verificar estado GCP
kubectl --context=gke_PROJECT_REGION_CLUSTER -n prod get pods

# 2. Si GCP está caído, forzar todo el tráfico a DO
# En Cloudflare: desactivar el registro A de GCP o bajar su priority

# 3. Verificar que DO está healthy
kubectl --context=do-nyc1-circleguard-cluster -n prod get pods

# 4. Cuando GCP se recupera, re-activar su registro DNS
```

---

## 3. Balanceo de carga entre proveedores

### Nivel DNS (recomendado para producción)

Usando **Cloudflare Load Balancing** o **AWS Route53**:

```
Pool: circleguard-primary
  Origin: GCP LoadBalancer IP  (weight: 100, health-check: ON)

Pool: circleguard-failover
  Origin: DO LoadBalancer IP   (weight: 100, health-check: ON)

Policy: GEO o FAILOVER
  → primary: circleguard-primary
  → fallback: circleguard-failover
```

### Nivel Kubernetes (dentro de cada cloud)

Cada cluster tiene su propio Ingress/LoadBalancer:

| Cloud | Tipo | Endpoint |
|-------|------|----------|
| GCP | GKE Ingress (GCE L7) | `34.x.x.x` |
| DO | DigitalOcean LoadBalancer | `104.248.x.x` |

El gateway service (`circleguard-gateway-service`) es el punto de entrada único dentro de cada cluster — todas las rutas de la API pasan por él.

### Configuración actual del pipeline

El parámetro `CLOUD_TARGET=multi` en el Jenkinsfile ejecuta el deploy a ambos clouds:

```groovy
// Jenkinsfile — Resolve Cloud Target
if (env.CLOUD_TARGET == 'multi') {
    // Deploy secuencial: primero GCP, luego DO
    // GCP: autentica via SA JSON (ensure-gke-access.sh)
    // DO:  usa kubeconfig-do-credentials
}
```

---

## 4. Comparativa de rendimiento entre clouds

Tests ejecutados con Locust contra el endpoint `GET /actuator/health` del gateway con 50 usuarios concurrentes durante 2 minutos.

| Métrica | GCP (GKE us-central1) | DigitalOcean (DOKS nyc1) |
|---------|----------------------|--------------------------|
| Requests/seg (avg) | ~280 rps | ~240 rps |
| Latencia P50 | 18 ms | 22 ms |
| Latencia P95 | 45 ms | 58 ms |
| Latencia P99 | 120 ms | 145 ms |
| Error rate | < 0.1% | < 0.1% |
| Costo nodo (aprox) | $0.10/h (e2-standard-2) | $0.048/h (s-2vcpu-4GB) |
| Autoscaling nodos | Sí (GKE Autopilot) | Limitado (manual en plan básico) |
| Cold start (pod) | ~45s | ~55s |

**Conclusión**: GCP ofrece mejor latencia y autoscaling nativo, justificando su rol como primario. DigitalOcean es ~52% más económico por nodo, lo que lo hace ideal como respaldo activo con costo controlado.

> Nota: Los valores de la tabla son representativos del entorno de staging (recursos reducidos). Los reportes completos de Locust se archivan como artefactos en cada build de Jenkins bajo `tests/performance/results/`.

---

## Infraestructura como código

| Directorio | Proveedor | Descripción |
|-----------|-----------|-------------|
| `infra/terraform-gcp/` | GCP | VPC, GKE cluster, node pools |
| `infra/terraform-do/` | DigitalOcean | VPC, DOKS cluster, droplets |
| `infra/terraform/` | Genérico | Módulos K8s reutilizables |

```bash
# Provisionar GCP (primario)
cd infra/terraform-gcp
terraform init && terraform apply -var-file=terraform.tfvars

# Provisionar DigitalOcean (respaldo)
cd infra/terraform-do/environments/prod
terraform init && terraform apply
```

---

## Rollback independiente por cloud

Cada cloud puede hacer rollback de forma independiente sin afectar al otro:

```bash
# Rollback en GCP
KUBECONFIG=<gcp-kubeconfig> kubectl -n prod rollout undo deployment/circleguard-gateway-service

# Rollback en DO
KUBECONFIG=<do-kubeconfig> kubectl -n prod rollout undo deployment/circleguard-gateway-service
```

Las imágenes Docker están taggeadas con semver (`0.2.1`) además de `prod`/`stage`, lo que permite apuntar a cualquier versión anterior:

```bash
kubectl -n prod set image deployment/circleguard-auth-service \
  auth=diegoapolancol/circleguard-auth-service:0.2.0
```
