# Guia de Uso - Terraform Kubernetes

Este modulo configura el acceso a Kubernetes y los secrets de Docker Hub.

## Prerequisitos

1. Acceso a un cluster Kubernetes (local con kubeconfig, DOKS o GKE)
2. Credentials de Docker Hub para pull de imagenes

## Uso

### Desarrollo

```bash
cd infra/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Editar con tus credenciales
terraform init
terraform apply
```

### Stage

```bash
cd infra/terraform/environments/stage
terraform init
terraform apply
```

### Produccion

```bash
cd infra/terraform/environments/prod
terraform init
terraform apply
```

## Variables Requeridas

```hcl
kubeconfig_path    = "../../../kubeconfig-credentials.yaml"  # Ruta al kubeconfig
dockerhub_username = "tu-usuario"                              # Usuario Docker Hub
dockerhub_password = "tu-token"                                # Token/password
dockerhub_email    = "tu-email@ejemplo.com"                    # Email
environments       = ["dev"]                                   # Namespace(s) a configurar
```

## Configuracion con GKE (opcional)

En lugar de usar kubeconfig local, puedes configurar el provider para usar GKE:

```hcl
use_gke           = true
gcp_project       = "mi-proyecto-gcp"
gke_cluster_name  = "circleguard-cluster"
gke_cluster_location = "us-central1"
```

 Asegurate de tener `GOOGLE_APPLICATION_CREDENTIALS` configurado con un service account que tenga acceso al cluster.

## Configuracion con DigitalOcean (DOKS)

Para DOKS, usa el kubeconfig del cluster y mantiene `use_gke=false`:

```hcl
kubeconfig_path = "../../../kubeconfig-do.yaml"
use_gke = false
```

## Secrets Creadors

El modulo `docker-secret` crea un Kubernetes Secret de tipo `kubernetes.io/dockerconfigjson` en cada namespace especificado. Este secret es usado por Kubernetes para hacer pull de imagenes privadas de Docker Hub.

## Backend Remoto

Igual que en `terraform-gcp`, el estado se almacena en GCS:
- Bucket: `circleguard-tfstate`
- Prefijos: `terraform-k8s/dev`, `terraform-k8s/stage`, `terraform-k8s/prod`

## Notas

- Las variables `dockerhub_username`, `dockerhub_password` y `qr_secret` son sensibles y no deben ser commiteadas
- El archivo `terraform.tfvars` debe estar en `.gitignore` (ya configurado en el root del proyecto)