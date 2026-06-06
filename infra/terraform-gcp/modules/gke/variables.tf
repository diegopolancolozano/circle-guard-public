variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Region donde crear el cluster GKE (regional = alta disponibilidad)"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster GKE"
  type        = string
  default     = "circleguard-cluster"
}

variable "network_name" {
  description = "Nombre de la red VPC donde desplegar el cluster"
  type        = string
}

variable "subnet_name" {
  description = "Nombre de la subred donde desplegar los nodos"
  type        = string
}

variable "pods_range_name" {
  description = "Nombre del rango secundario para Pods (debe existir en la subred)"
  type        = string
}

variable "services_range_name" {
  description = "Nombre del rango secundario para Services (debe existir en la subred)"
  type        = string
}

variable "node_count" {
  description = "Numero inicial de nodos por zona"
  type        = number
  default     = 1
}

variable "min_nodes" {
  description = "Minimo de nodos para el autoscaler"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximo de nodos para el autoscaler"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Tipo de maquina para los nodos"
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Tamano del disco de cada nodo en GB"
  type        = number
  default     = 50
}

variable "release_channel" {
  description = "Canal de actualizacion del cluster (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "enable_private_nodes" {
  description = "Usar IPs privadas para los nodos (recomendado en produccion)"
  type        = bool
  default     = true
}

variable "master_ipv4_cidr_block" {
  description = "CIDR para el plano de control privado (no debe solaparse con VPC)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs autorizados para acceder al API server de Kubernetes"
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

variable "environment" {
  description = "Etiqueta de ambiente (dev, stage, prod)"
  type        = string
  default     = "stage"
}

variable "deletion_protection" {
  description = "Proteccion contra borrado accidental (false en dev/stage)"
  type        = bool
  default     = false
}

variable "disk_type" {
  description = "Tipo de disco para los nodos. pd-standard = HDD (sin cuota SSD). pd-balanced = SSD balanceado."
  type        = string
  default     = "pd-standard"
}
