variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig"
  type        = string
  default     = null
}

variable "use_gke" {
  description = "Usar GKE para configurar el provider"
  type        = bool
  default     = false
}

variable "gcp_project" {
  description = "ID del proyecto GCP"
  type        = string
  default     = ""
}

variable "gke_cluster_name" {
  description = "Nombre del cluster GKE"
  type        = string
  default     = ""
}

variable "gke_cluster_location" {
  description = "Zona o region del cluster GKE"
  type        = string
  default     = ""
}
