variable "bucket_name" {
  description = "Nombre del bucket GCS para el estado de Terraform"
  type        = string
}

variable "location" {
  description = "Ubicacion del bucket"
  type        = string
  default     = "US"
}

variable "admin_member" {
  description = "Miembro IAM con acceso de administrador al bucket (ej: user:admin@example.com)"
  type        = string
}
