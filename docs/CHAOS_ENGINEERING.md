# Chaos Engineering — CircleGuard

## Objetivo

Validar la resiliencia del sistema ante fallos reales: pods que caen, servicios que desaparecen temporalmente y presión de CPU. Los experimentos demuestran que los patrones de resiliencia implementados (Circuit Breaker, probes) funcionan correctamente.

## Herramienta

Sin dependencia de frameworks externos (Chaos Mesh / Litmus requieren instalación en cluster). Los experimentos se ejecutan con `kubectl` + `bash` y generan un reporte Markdown.

```bash
# Todos los experimentos en stage
scripts/ci/chaos-experiments.sh stage all

# Experimento individual
scripts/ci/chaos-experiments.sh stage pod-kill
scripts/ci/chaos-experiments.sh stage scale-zero
scripts/ci/chaos-experiments.sh stage cpu-stress
```

Los reportes se guardan en `tests/chaos/results/chaos-<env>-<timestamp>.md`.

## Experimentos

### 1. Pod Kill — circleguard-auth-service

| Campo | Valor |
|:---|:---|
| **Hipótesis** | Matar el pod activa el restart automático de Kubernetes; el servicio se recupera en < 60s |
| **Método** | `kubectl delete pod --grace-period=0 --force` |
| **Criterio de éxito** | `readyReplicas == desiredReplicas` en < 60s |
| **Patrón validado** | Kubernetes restartPolicy + startupProbe |

**Por qué importa:** Un pod que falla (OOMKilled, excepción no controlada) debe recuperarse automáticamente sin intervención manual.

### 2. Scale to Zero — circleguard-identity-service + Circuit Breaker

| Campo | Valor |
|:---|:---|
| **Hipótesis** | Con identity-service a 0 réplicas, el Circuit Breaker de auth-service entra en estado OPEN y el fallback local toma el control |
| **Método** | `kubectl scale --replicas=0` + observación de métrica `resilience4j_circuitbreaker_state` |
| **Criterio de éxito** | auth-service sigue respondiendo (usa UUID determinístico local) |
| **Patrón validado** | Circuit Breaker + Strategy (fallback a LocalIdentityMappingStrategy) |

**Por qué importa:** En un sistema distribuido, la caída de un microservicio dependiente no debe propagar el fallo en cascada.

### 3. CPU Stress — Impacto en latencia

| Campo | Valor |
|:---|:---|
| **Hipótesis** | Saturar la CPU del nodo aumenta la latencia p95; la alerta `HighLatency` de Prometheus debería activarse si p95 > 2s |
| **Método** | Pod `busybox` ejecutando `yes > /dev/null` en 4 threads durante 30s |
| **Criterio de éxito** | Sistema sigue respondiendo; las alertas se ven en AlertManager |
| **Patrón validado** | Prometheus alerting + readinessProbe (evita tráfico a pods lentos) |

## Resultados esperados y mejoras

| Experimento | Resultado esperado | Mejora si falla |
|:---|:---|:---|
| Pod Kill | Recovery < 60s | Bajar `failureThreshold` en startupProbe |
| Scale to Zero | Circuit Breaker abre en < 10s | Reducir `sliding-window-size` en Resilience4j |
| CPU Stress | p95 no supera 2s (alert no dispara) | Aumentar `requests.cpu` en deployment |

## Integración en pipeline

El stage de Chaos se ejecuta solo en modo `full` sobre `stage`, después de las pruebas E2E:

```groovy
stage("Chaos Experiments") {
    when { branch "main"; expression { env.PIPELINE_MODE == 'full' } }
    steps {
        sh "scripts/ci/chaos-experiments.sh stage all"
    }
    post {
        always { archiveArtifacts artifacts: "tests/chaos/results/*.md" }
    }
}
```
