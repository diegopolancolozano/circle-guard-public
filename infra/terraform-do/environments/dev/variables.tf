variable "region" {
  description = "Region de DigitalOcean"
  type        = string
  default     = "nyc1"
}

variable "vpc_name" {
  description = "Nombre de la VPC"
  type        = string
  default     = "circleguard-dev-vpc"
}

variable "vpc_ip_range" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.30.0.0/20"
}

variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "circleguard-dev"
}

variable "k8s_version" {
  description = "Version de Kubernetes"
  type        = string
}

variable "node_pool_name" {
  description = "Nombre del node pool"
  type        = string
  default     = "default-pool"
}

variable "node_size" {
  description = "Tamaño de nodo"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Cantidad de nodos"
  type        = number
  default     = 2
}

variable "node_auto_scale" {
  description = "Autoescalado"
  type        = bool
  default     = false
}

variable "node_min_count" {
  description = "Minimo de nodos"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximo de nodos"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags del cluster"
  type        = list(string)
  default     = ["circleguard", "dev"]
}

variable "node_tags" {
  description = "Tags del node pool"
  type        = list(string)
  default     = ["circleguard", "dev"]
}

variable "node_labels" {
  description = "Labels del node pool"
  type        = map(string)
  default     = {
    env = "dev"
  }
}
