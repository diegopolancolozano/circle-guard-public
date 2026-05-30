variable "region" {
  description = "Region de DigitalOcean"
  type        = string
  default     = "nyc1"
}

variable "vpc_name" {
  description = "Nombre de la VPC"
  type        = string
  default     = "circleguard-stage-vpc"
}

variable "vpc_ip_range" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.30.16.0/20"
}

variable "cluster_name" {
  description = "Nombre del cluster"
  type        = string
  default     = "circleguard-stage"
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
  default     = ["circleguard", "stage"]
}

variable "node_tags" {
  description = "Tags del node pool"
  type        = list(string)
  default     = ["circleguard", "stage"]
}

variable "node_labels" {
  description = "Labels del node pool"
  type        = map(string)
  default     = {
    env = "stage"
  }
}

# ── Jenkins Droplet ──────────────────────────────────────────────────────────
variable "cluster_vpc_id" {
  description = "UUID de la VPC del cluster DOKS existente. Dejar vacío para usar la VPC gestionada por el módulo vpc."
  type        = string
  default     = ""
}

variable "jenkins_droplet_size" {
  description = "Tamano del Droplet para Jenkins"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "jenkins_ssh_public_key" {
  description = "Clave publica SSH para acceder al Droplet Jenkins (formato OpenSSH). Dejar vacio para no configurar SSH key"
  type        = string
  default     = ""
}

variable "jenkins_allowed_ssh_cidrs" {
  description = "CIDRs habilitados para SSH al Jenkins Droplet"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
