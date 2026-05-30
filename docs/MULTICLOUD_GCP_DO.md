# Estrategia Multi-Cloud: DigitalOcean + GCP

Este documento define una estrategia práctica para operar CircleGuard con DigitalOcean y GCP en etapas, sin romper el flujo actual.

## Objetivo

- Tener despliegues repetibles en **DOKS (DigitalOcean)** y **GKE (GCP)**.
- Mantener promoción controlada por ambientes.
- Evitar acoplar todo en una sola pipeline desde el día 1.

## Modelo recomendado por etapas

### Etapa 1 (actual, incremental)

- Un pipeline con modos `reduced` y `full`.
- `CLOUD_TARGET` configurable (`local`, `digitalocean`, `gcp`, `multi`).
- Un solo kubeconfig activo por ejecución.

### Etapa 2

- Dos credenciales kubeconfig separadas en Jenkins:
  - `kubeconfig-do-credentials`
  - `kubeconfig-gcp-credentials`
- Dos jobs o dos ramas de despliegue controladas por cloud.

### Etapa 3

- Promoción multi-cloud real con verificación de salud en ambos clusters.
- Estrategia de rollback independiente por proveedor.

## Branching sugerido por cloud

- `dev`: pruebas rápidas y validación de cambios.
- `stage`: validación funcional y performance.
- `main`: release estable y promoción controlada.

Cloud target por defecto sugerido:

- `dev` -> `digitalocean`
- `stage` -> `gcp`
- `main` -> `multi` (cuando exista doble despliegue real)

## Jenkins (parámetros)

Parámetros relevantes en el pipeline:

- `PIPELINE_MODE`: `reduced` o `full`
- `CLOUD_TARGET`: `local`, `digitalocean`, `gcp`, `multi`
- `TEARDOWN_AFTER_MINUTES`: minutos para apagar ambiente en `full`

Mapeo de credenciales kubeconfig usado por el pipeline:

- `local` -> `kubeconfig-credentials`
- `digitalocean` -> `kubeconfig-do-credentials`
- `gcp` -> `kubeconfig-gcp-credentials`
- `multi` -> ejecutar dos veces (`digitalocean` y `gcp`)

## Ejecucion recomendada (multi-cloud real)

Para cubrir ambos clouds, ejecutar dos veces:

1) `PIPELINE_MODE=full`, `CLOUD_TARGET=digitalocean`
2) `PIPELINE_MODE=full`, `CLOUD_TARGET=gcp`

## Terraform

Base existente:

- `infra/terraform-gcp`: stack específico de GCP.
- `infra/terraform`: configuración Kubernetes genérica y módulos reutilizables.

Uso sugerido por cloud:

- **DigitalOcean (DOKS)**: usar `infra/terraform` con `kubeconfig_path` del cluster DOKS (y `use_gke=false`).
- **GCP (GKE)**: usar `infra/terraform-gcp` o `infra/terraform` con `use_gke=true`.

Siguiente mejora recomendada:

- crear `infra/terraform-do` para recursos específicos de DigitalOcean,
- homologar outputs entre GCP y DO,
- estandarizar variables de entorno por ambiente.

## Credenciales mínimas por cloud

### DigitalOcean

- Token API de DigitalOcean.
- kubeconfig de DOKS para Jenkins.

### GCP

- Service Account o kubeconfig de GKE.
- permisos mínimos para acceso al cluster y deploy.

## Rollback multi-cloud

- mantener la versión estable anterior por cloud,
- rollback independiente si falla solo un proveedor,
- registrar incidentes y tiempos de recuperación.

## Evidencia para presentación

- ejecución en modo `full` con `CLOUD_TARGET=digitalocean`,
- ejecución en modo `full` con `CLOUD_TARGET=gcp`,
- plan de convergencia a `CLOUD_TARGET=multi`.
