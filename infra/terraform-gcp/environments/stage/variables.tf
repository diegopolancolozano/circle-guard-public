# ---------------------------------------------------------------------------
# GCP project / region
# ---------------------------------------------------------------------------
variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Region de GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona de GCP (para las VMs de CI)"
  type        = string
  default     = "us-central1-a"
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
variable "network_name" {
  description = "Nombre base de la red VPC"
  type        = string
  default     = "circleguard-vpc"
}

variable "subnet_name" {
  description = "Nombre base de la subred"
  type        = string
  default     = "circleguard-subnet"
}

variable "subnet_cidr" {
  description = "CIDR principal de la subred"
  type        = string
  default     = "10.20.10.0/24"
}

variable "pods_cidr" {
  description = "CIDR secundario para Pods GKE"
  type        = string
  default     = "10.100.0.0/16"
}

variable "services_cidr" {
  description = "CIDR secundario para Services GKE"
  type        = string
  default     = "10.101.0.0/20"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs autorizados para SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_jenkins_firewall" {
  description = "Habilitar regla de firewall para Jenkins en puerto 8080"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# GKE cluster
# ---------------------------------------------------------------------------
variable "gke_cluster_name" {
  description = "Nombre del cluster GKE"
  type        = string
  default     = "circleguard-stage"
}

variable "gke_node_count" {
  description = "Numero inicial de nodos"
  type        = number
  default     = 1
}

variable "gke_min_nodes" {
  description = "Minimo de nodos (autoscaler)"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximo de nodos (autoscaler)"
  type        = number
  default     = 3
}

variable "gke_machine_type" {
  description = "Tipo de maquina para los nodos GKE"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_disk_size_gb" {
  description = "Tamano de disco de cada nodo en GB"
  type        = number
  default     = 50
}

variable "gke_enable_private_nodes" {
  description = "Usar IPs privadas para los nodos"
  type        = bool
  default     = true
}

variable "gke_master_cidr" {
  description = "CIDR para el plano de control privado de GKE"
  type        = string
  default     = "172.16.0.0/28"
}

variable "gke_master_authorized_networks" {
  description = "CIDRs autorizados para acceder al API server de GKE"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    }
  ]
}

# ---------------------------------------------------------------------------
# VMs de CI
# ---------------------------------------------------------------------------
variable "ssh_public_key" {
  description = "Clave publica SSH en formato OpenSSH"
  type        = string
}

variable "ssh_user" {
  description = "Usuario Linux usado por SSH"
  type        = string
  default     = "deployer"
}

variable "machines" {
  description = "Maquinas CI a crear en GCP"
  type = map(object({
    machine_type    = string
    disk_size_gb    = number
    tags            = list(string)
    startup_profile = string
  }))
  default = {
    jenkins = {
      machine_type    = "e2-standard-2"
      disk_size_gb    = 50
      tags            = ["jenkins", "ssh", "http"]
      startup_profile = "jenkins"
    }
  }
}
