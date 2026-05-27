variable "network_name" {
  description = "Nombre de la red VPC"
  type        = string
}

variable "subnet_name" {
  description = "Nombre de la subred"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR para la subred"
  type        = string
}

variable "region" {
  description = "Region de GCP"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Rangos CIDR autorizados para SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_jenkins_firewall" {
  description = "Habilitar regla de firewall para Jenkins (puerto 8080)"
  type        = bool
  default     = true
}

variable "pods_cidr" {
  description = "CIDR secundario para Pods de GKE"
  type        = string
  default     = "10.100.0.0/16"
}

variable "services_cidr" {
  description = "CIDR secundario para Services de GKE"
  type        = string
  default     = "10.101.0.0/20"
}
