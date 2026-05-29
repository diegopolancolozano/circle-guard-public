variable "name" {
  description = "Nombre de la VPC"
  type        = string
}

variable "region" {
  description = "Region de la VPC"
  type        = string
}

variable "ip_range" {
  description = "CIDR de la VPC"
  type        = string
}

variable "description" {
  description = "Descripcion de la VPC"
  type        = string
  default     = "CircleGuard VPC"
}
