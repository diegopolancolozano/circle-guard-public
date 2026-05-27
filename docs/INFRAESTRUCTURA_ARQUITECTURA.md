# Arquitectura de Infraestructura – CircleGuard

## 1. Diagrama de Arquitectura General

```mermaid
graph TB
    subgraph "Google Cloud Platform"
        subgraph "VPC (10.20.0.0/16)"
            subgraph "dev (10.20.0.0/24)"
                VM_DEV_J["Jenkins VM<br/>e2-standard-2<br/>40GB"]
                VM_DEV_R["Runner VM<br/>e2-standard-2<br/>30GB"]
            end

            subgraph "stage (10.20.10.0/24)"
                VM_STG_J["Jenkins VM<br/>e2-standard-2<br/>40GB"]
                VM_STG_R["Runner VM<br/>e2-standard-2<br/>30GB"]
            end

            subgraph "prod (10.20.20.0/24)"
                VM_PROD_J["Jenkins VM<br/>e2-standard-2<br/>50GB"]
                VM_PROD_R["Runner VM<br/>e2-standard-2<br/>40GB"]
            end
        end

        FW_SSH["FW: SSH (22)"]
        FW_JENKINS["FW: Jenkins (8080)"]
        FW_HTTP["FW: HTTP/HTTPS (80,443)"]
        FW_INT["FW: Internal (all)"]

        GCS_STATE["GCS Bucket<br/>Terraform State<br/>circleguard-tfstate"]
    end

    subgraph "Kubernetes Cluster"
        NS_DEV["Namespace: dev"]
        NS_STAGE["Namespace: stage"]
        NS_PROD["Namespace: prod"]
    end

    subgraph "CircleGuard Services"
        AUTH["Auth Service"]
        IDENTITY["Identity Service"]
        PROMOTION["Promotion Service"]
        GATEWAY["Gateway Service"]
        DASHBOARD["Dashboard Service"]
        FILE["File Service"]
        FORM["Form Service"]
        NOTIF["Notification Service"]
    end

    subgraph "Infra Services"
        PG["PostgreSQL 16"]
        NEO["Neo4j 5.26"]
        REDIS["Redis 7.2"]
        KAFKA["Kafka 7.6"]
        LDAP["OpenLDAP 1.5"]
    end

    VM_DEV_J -->|kubectl| NS_DEV
    VM_STG_J -->|kubectl| NS_STAGE
    VM_PROD_J -->|kubectl| NS_PROD
    NS_DEV --> AUTH
    NS_DEV --> IDENTITY
    NS_DEV --> PROMOTION
```

### 1.2 DigitalOcean (DOKS)

```mermaid
graph TB
    subgraph "DigitalOcean"
        DO_VPC["VPC DO<br/>10.30.0.0/16"]
        DO_DOKS["DOKS Cluster<br/>dev/stage/prod"]
        DO_SPACES["Spaces Bucket<br/>Terraform State"]
    end

    DO_VPC --> DO_DOKS
    DO_SPACES --> DO_DOKS
```

---

## 2. Estructura de Terraform (Modular)

```mermaid
graph TD
    subgraph "infra/terraform-gcp/"
        ENV_DEV["environments/dev/<br/>main.tf + terraform.tfvars"]
        ENV_STG["environments/stage/<br/>main.tf + terraform.tfvars"]
        ENV_PROD["environments/prod/<br/>main.tf + terraform.tfvars"]
        GLOBAL["global/<br/>main.tf<br/>(bootstrap state bucket)"]

        subgraph "modules/"
            VPC["vpc/<br/>VPC, Subnets,<br/>Firewall Rules"]
            COMPUTE["compute/<br/>VMs, Static IPs,<br/>Startup Scripts"]
            RS["remote-state/<br/>GCS Bucket +<br/>Versioning"]
        end

        ENV_DEV --> VPC
        ENV_DEV --> COMPUTE
        ENV_DEV --> RS
        ENV_STG --> VPC
        ENV_STG --> COMPUTE
        ENV_PROD --> VPC
        ENV_PROD --> COMPUTE
        GLOBAL --> RS
    end

    subgraph "infra/terraform/"
        K8S_DEV["environments/dev/<br/>main.tf"]
        K8S_STG["environments/stage/<br/>main.tf"]
        K8S_PROD["environments/prod/<br/>main.tf"]

        subgraph "modules/"
            DS["docker-secret/<br/>Docker Hub Pull Secret"]
        end

        K8S_DEV --> DS
        K8S_STG --> DS
        K8S_PROD --> DS
    end

    subgraph "infra/terraform-do/"
        DO_DEV["environments/dev/<br/>main.tf + backend.hcl"]
        DO_STG["environments/stage/<br/>main.tf + backend.hcl"]
        DO_PROD["environments/prod/<br/>main.tf + backend.hcl"]

        subgraph "modules/"
            DO_VPC_M["vpc/<br/>VPC DO"]
            DO_DOKS_M["doks-cluster/<br/>DOKS Cluster"]
        end

        DO_DEV --> DO_VPC_M
        DO_DEV --> DO_DOKS_M
        DO_STG --> DO_VPC_M
        DO_STG --> DO_DOKS_M
        DO_PROD --> DO_VPC_M
        DO_PROD --> DO_DOKS_M
    end
```

---

## 3. Flujo de Estado Remoto (GCS Backend)

```mermaid
sequenceDiagram
    participant D as Desarrollador
    participant TF as Terraform
    participant GCS as GCS Bucket<br/>(circleguard-tfstate)
    participant GCP as GCP API

    D->>TF: terraform init
    TF->>GCS: Conectar backend GCS
    GCS-->>TF: Descargar estado actual

    D->>TF: terraform plan
    TF->>GCP: Consultar estado real
    GCP-->>TF: Recursos actuales
    TF-->>D: Plan de cambios

    D->>TF: terraform apply
    TF->>GCS: Bloquear estado (Lock)
    TF->>GCP: Crear/Actualizar recursos
    GCP-->>TF: Resultado
    TF->>GCS: Actualizar estado + Liberar lock
    GCS-->>TF: Confirmacion
    TF-->>D: Apply completo
```

### 3.2 Estado remoto en DigitalOcean (Spaces)

- Bucket: `circleguard-tfstate-do`
- Prefijos: `terraform-do/dev`, `terraform-do/stage`, `terraform-do/prod`
- Backend tipo `s3` con endpoint de Spaces

---

## 4. Modulos de Terraform

### 4.1 Modulo `vpc`

| Recurso | Descripcion |
|---------|-------------|
| `google_compute_network` | Red VPC |
| `google_compute_subnetwork` | Subred por ambiente |
| `google_compute_firewall.allow_ssh` | SSH (puerto 22) |
| `google_compute_firewall.allow_jenkins` | Jenkins (puerto 8080) |
| `google_compute_firewall.allow_http_https` | HTTP/HTTPS (80, 443) |
| `google_compute_firewall.allow_internal` | Trafico interno en la VPC |

### 4.2 Modulo `compute`

| Recurso | Descripcion |
|---------|-------------|
| `google_compute_address` | IP publica estatica por VM |
| `google_compute_instance` | Instancias VM con startup scripts |

### 4.3 Modulo `remote-state`

| Recurso | Descripcion |
|---------|-------------|
| `google_storage_bucket` | Bucket GCS con versioning para estado Terraform |
| `google_storage_bucket_iam_member` | Permisos de administrador al bucket |

### 4.4 Modulo `docker-secret`

| Recurso | Descripcion |
|---------|-------------|
| `kubernetes_secret_v1` | Secret de tipo dockerconfigjson en cada namespace |

---

## 5. Ambientes

| Ambiente | Subred CIDR | VMs | GCS State Prefix |
|----------|-------------|-----|------------------|
| **dev** | `10.20.0.0/24` | Jenkins (40GB) + Runner (30GB) | `terraform-gcp/dev` |
| **stage** | `10.20.10.0/24` | Jenkins (40GB) + Runner (30GB) | `terraform-gcp/stage` |
| **prod** | `10.20.20.0/24` | Jenkins (50GB) + Runner (40GB) | `terraform-gcp/prod` |

### DigitalOcean (DOKS)

| Ambiente | VPC CIDR | Cluster | State Prefix |
|----------|----------|---------|--------------|
| **dev** | `10.30.0.0/20` | `circleguard-dev` | `terraform-do/dev` |
| **stage** | `10.30.16.0/20` | `circleguard-stage` | `terraform-do/stage` |
| **prod** | `10.30.32.0/20` | `circleguard-prod` | `terraform-do/prod` |

---

## 6. Backend Remoto

El estado de Terraform se almacena en un **bucket GCS** con las siguientes caracteristicas:

- **Bucket**: `circleguard-tfstate-<suffix>`
- **Ubicacion**: US (multi-region)
- **Versioning**: Habilitado (historial de cambios)
- **Lifecycle**: Elimina versiones antiguas despues de 5 versiones
- **IAM**: Solo service accounts con `roles/storage.objectAdmin`

Cada ambiente y cada proyecto de Terraform usa un **prefix** distinto dentro del mismo bucket para mantener los estados separados y evitar conflictos:

| Proyecto | Prefix |
|----------|--------|
| GCP Infra - dev | `terraform-gcp/dev` |
| GCP Infra - stage | `terraform-gcp/stage` |
| GCP Infra - prod | `terraform-gcp/prod` |
| K8s Config - dev | `terraform-k8s/dev` |
| K8s Config - stage | `terraform-k8s/stage` |
| K8s Config - prod | `terraform-k8s/prod` |
| DO Infra - dev | `terraform-do/dev` |
| DO Infra - stage | `terraform-do/stage` |
| DO Infra - prod | `terraform-do/prod` |

---

## 7. Bootstrap del Bucket de Estado

Antes de usar los entornos, se debe crear el bucket de estado ejecutando:

```bash
cd infra/terraform-gcp/global
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con los valores del proyecto
terraform init
terraform apply
```

Luego, en cada entorno:

```bash
cd infra/terraform-gcp/environments/dev  # o stage, prod
terraform init
terraform plan
terraform apply
```

---

## 8. Seguridad

- Las VMs solo exponen puertos esenciales (22, 8080, 80, 443)
- SSH restringido por CIDR configurable
- Trafico interno permitido dentro de la VPC
- Estado de Terraform en GCS con versioning y IAM restringido
- Secrets de Docker Hub manejados como variables sensibles en Terraform
- Claves SSH inyectadas via metadata, no hardcodeadas
