# FinOps — Gestión de costos CircleGuard

## Objetivo

Visibilizar y reducir el costo de infraestructura de CircleGuard aplicando prácticas FinOps: monitorear utilización real vs. recursos reservados, identificar pods sobredimensionados y configurar políticas de ahorro automático.

## Dashboard Grafana — CircleGuard FinOps

**Ubicación:** Grafana → CircleGuard → *CircleGuard FinOps* (`uid: circleguard-finops`)

| Panel | Métrica |
|:---|:---|
| Pods Running | Pods activos en dev/stage/prod |
| CPU Requested | Suma de CPU reservada (cores) |
| Memory Requested | Suma de memoria reservada (GiB) |
| Est. Monthly Cost | Estimación DigitalOcean (3× s-2vcpu-4gb @ $24/node) |
| CPU Utilization vs Request | Uso real vs. reservado por servicio |
| Memory Utilization vs Request | Uso real vs. reservado por servicio |
| CPU Efficiency | Ratio uso/reserva (objetivo: > 40%) |
| Idle/Oversized Pods | Pods cuya reserva supera 2× el uso real |

## Costos de infraestructura

### DigitalOcean (ambiente de demo)

| Recurso | Spec | Costo/mes |
|:---|:---|:---|
| DOKS Worker × 3 | s-2vcpu-4gb | $72 USD |
| Load Balancer | 1 LB | $12 USD |
| Container Registry | Starter | $0 USD |
| **Total DO** | | **$84 USD/mes** |

### GCP (ambiente de producción)

| Recurso | Spec | Costo/mes |
|:---|:---|:---|
| GKE Worker × 3 | e2-standard-2 | ~$96 USD |
| GCS bucket (tfstate) | < 1 GB | < $1 USD |
| Egress | Estimado 10 GB | ~$1.20 USD |
| **Total GCP** | | **~$98 USD/mes** |

### Multi-Cloud (DO + GCP simultáneo)

| Concepto | Costo/mes |
|:---|:---|
| DigitalOcean (dev/stage) | $84 USD |
| GCP (prod) | $98 USD |
| **Total estimado** | **$182 USD/mes** |

## Estrategias de ahorro implementadas

### 1. Teardown automático de entornos dev/stage

El Jenkinsfile incluye `TEARDOWN_AFTER_MINUTES` que escala todos los deployments a 0 después de N minutos. Esto ahorra hasta el 60% del costo cuando los entornos no están en uso.

```bash
# Teardown manual inmediato
scripts/ci/k8s-teardown.sh stage
# Ahorro estimado: ~$42/mes (50% de DO si stage está inactivo la mitad del tiempo)
```

### 2. Scale-down de infraestructura pesada

Neo4j y OpenLDAP se escalan a 0 en dev y stage (patch en overlays). Ahorra ~512 MB de RAM por ambiente.

### 3. Recursos conservadores para servicios

Todos los servicios Java usan `-Xms128m -Xmx384m`. Esto permite mayor densidad de pods en nodos pequeños.

### 4. Análisis de eficiencia con Grafana

El panel **CPU Efficiency** muestra el ratio `uso_real / reservado`. Los servicios con ratio < 20% son candidatos a reducir su `resources.requests.cpu`.

**Acción recomendada si CPU efficiency < 20%:**
```yaml
# En services-deployments.yaml
resources:
  requests:
    cpu: 50m    # reducir desde 100m
    memory: 128Mi
```

### 5. Spot Instances (GCP Preemptible / DO Reserved)

Para entornos de desarrollo, usar nodos preemptibles de GCP reduce el costo ~70%:

```hcl
# infra/terraform-gcp/modules/compute/main.tf
scheduling {
  preemptible  = true
  automatic_restart = false
}
```

## Monitoreo continuo de costos

```bash
# Ver utilización actual
kubectl top pods -n stage
kubectl top nodes

# Ver recursos reservados vs límites
kubectl describe nodes | grep -A5 "Allocated resources"
```

Alertas de FinOps configuradas en Prometheus (`k8s/monitoring/alertmanager.yaml`):
- `HighMemoryUsage` — JVM heap > 85%
- `CPUThrottling` — configurar si se agrega en las reglas de alerta

## Benchmark multi-cloud

| Métrica | DigitalOcean | GCP |
|:---|:---|:---|
| Tiempo cold start | ~5 min (DOKS) | ~7 min (GKE) |
| Costo/hora nodo 2vCPU 4GB | $0.033 | ~$0.040 |
| Uptime SLA | 99.95% | 99.95% |
| Latencia inter-zona | < 5ms | < 1ms |
| Panel de costo nativo | Billing dashboard | Cloud Billing |
