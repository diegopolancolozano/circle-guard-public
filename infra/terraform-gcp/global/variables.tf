variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Region de GCP"
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Nombre unico global para el bucket GCS de estado"
  type        = string
}

variable "state_bucket_location" {
  description = "Ubicacion del bucket de estado"
  type        = string
  default     = "US"
}
