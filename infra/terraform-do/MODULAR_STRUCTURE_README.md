# Guia de Uso - Terraform DigitalOcean (DOKS)

Este modulo crea infraestructura base en DigitalOcean y un cluster Kubernetes (DOKS) por ambiente.

## Prerequisitos

1. Terraform >= 1.6.0
2. Token de DigitalOcean con permisos de Kubernetes y VPC
3. (Opcional) Spaces bucket para estado remoto

## Flujo de despliegue

### Paso 1: Configurar backend remoto (opcional pero recomendado)

Cada ambiente tiene un `backend.hcl.example`. Copia y completa los valores:

```bash
cd infra/terraform-do/environments/dev
cp backend.hcl.example backend.hcl
```

Luego inicializa Terraform con el backend:

```bash
terraform init -backend-config=backend.hcl
```

### Paso 2: Crear el cluster

```bash
cd infra/terraform-do/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Editar variables: k8s_version, node_size, etc
terraform init
terraform plan
terraform apply
```

## Variables importantes

- `k8s_version`: version de DOKS (obtener con `doctl kubernetes options versions`)
- `node_size`: tamaño de nodos (ej: `s-2vcpu-4gb`)
- `node_count`: cantidad de nodos
- `region`: region DO (ej: `nyc1`)

## Notas

- Los archivos `terraform.tfvars` no deben versionarse.
- El kubeconfig se puede obtener desde `doctl kubernetes cluster kubeconfig save <cluster_name>`.
