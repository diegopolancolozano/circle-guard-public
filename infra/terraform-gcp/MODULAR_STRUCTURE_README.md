# Guia de Uso - Terraform Modular

Este documento describe como usar la nueva estructura modular de Terraform.

## Prerequisitos

1. Google Cloud SDK instalado y autenticado:
   ```bash
   gcloud auth application-default login
   ```

2. Terraform >= 1.6.0 instalado

## Flujo de Despliegue

### Paso 1: Crear el bucket de estado (una sola vez)

```bash
cd infra/terraform-gcp/global

# Copiar el archivo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar con los valores de tu proyecto
# - project_id: ID de tu proyecto GCP
# - state_bucket_name: nombre unico para el bucket

# Inicializar y aplicar
terraform init
terraform apply
```

Esto crea el bucket GCS `circleguard-tfstate` con versioning habilitado.

### Paso 2: Desplegar ambientes

#### Desarrollo (dev)

```bash
cd infra/terraform-gcp/environments/dev
terraform init
terraform plan
terraform apply
```

#### Stage

```bash
cd infra/terraform-gcp/environments/stage
terraform init
terraform apply
```

#### Produccion

```bash
cd infra/terraform-gcp/environments/prod
terraform init
terraform apply
```

### Paso 3: Configurar Kubernetes

Despues de aprovisionar las VMs, configurar el acceso a K8s:

```bash
cd infra/terraform/environments/dev
terraform init
terraform apply
```

## Estructura de Archivos

### Modules

| Modulo | Descripcion |
|--------|-------------|
| `modules/vpc` | Crea VPC, subred y reglas de firewall |
| `modules/compute` | Crea VMs con IPs estaticas y scripts de inicio |
| `modules/remote-state` | Crea bucket GCS para estado remoto |

### Environments

Cada environment tiene:
- `main.tf` - Llama a los modulos con parametros del ambiente
- `variables.tf` - Definicion de variables
- `terraform.tfvars` - Valores especificos del ambiente

## Variables por Ambiente

### dev
- Subred: `10.20.0.0/24`
- VMs: Jenkins (40GB) + Runner (30GB)
- Prefijo estado: `terraform-gcp/dev`

### stage
- Subred: `10.20.10.0/24`
- VMs: Jenkins (40GB) + Runner (30GB)
- Prefijo estado: `terraform-gcp/stage`

### prod
- Subred: `10.20.20.0/24`
- VMs: Jenkins (50GB) + Runner (40GB)
- Prefijo estado: `terraform-gcp/prod`

## Comandos Utiles

```bash
# Ver plan sin aplicar
terraform plan -out=tfplan

# Aplicar con plan guardado
terraform apply tfplan

# Destruir recursos
terraform destroy

# Ver outputs
terraform output

# Ver estado actual
terraform show

# Lock de estado (automatico con backend GCS)
# Para desbloquear en caso de emergencia:
terraform force-unlock -force <lock-id>
```

## Notas de Seguridad

1. **No commitear archivos .tfvars** - Contienen claves SSH y datos sensibles
2. **Restringir SSH** - En `terraform.tfvars` configurar `allowed_ssh_cidrs` con tu IP
3. **Backend GCS** - El bucket usa versioning para mantener historial de estados
4. **IAM** - Solo el service account del proyecto tiene acceso al bucket

## Mantenimiento

- Para actualizar infraestructura: editar `terraform.tfvars` del ambiente y running `terraform apply`
- Para cambiar configuracion de modulos: editar los archivos en `modules/` y apply a todos los ambientes afectados
- Para destruir: usar `terraform destroy` en el environment correspondiente