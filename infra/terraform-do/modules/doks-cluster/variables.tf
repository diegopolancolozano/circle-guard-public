variable "cluster_name" {
  description = "Nombre del cluster DOKS"
  type        = string
}

variable "region" {
  description = "Region del cluster"
  type        = string
}

variable "k8s_version" {
  description = "Version de Kubernetes para DOKS"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC (opcional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags del cluster"
  type        = list(string)
  default     = []
}

variable "node_pool_name" {
  description = "Nombre del node pool"
  type        = string
}

variable "node_size" {
  description = "Tamaño de nodo"
  type        = string
}

variable "node_count" {
  description = "Cantidad de nodos"
  type        = number
}

variable "node_auto_scale" {
  description = "Autoescalado"
  type        = bool
  default     = false
}

variable "node_min_count" {
  description = "Minimo de nodos"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximo de nodos"
  type        = number
  default     = 3
}

variable "node_tags" {
  description = "Tags del node pool"
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Labels del node pool"
  type        = map(string)
  default     = {}
}
