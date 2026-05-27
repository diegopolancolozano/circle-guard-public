variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig (usar cuando use_gke = false)"
  type        = string
  default     = ""
}

variable "use_gke" {
  description = "Cuando true, Terraform obtiene credenciales del cluster GKE via ADC"
  type        = bool
  default     = true
}

variable "gcp_project" {
  description = "ID del proyecto GCP"
  type        = string
  default     = ""
}

variable "gke_cluster_name" {
  description = "Nombre del cluster GKE de produccion"
  type        = string
  default     = "circleguard-prod"
}

variable "gke_cluster_location" {
  description = "Region o zona del cluster GKE"
  type        = string
  default     = "us-central1"
}

variable "environments" {
  description = "Namespaces de despliegue"
  type        = set(string)
  default     = ["prod"]
}

variable "dockerhub_username" {
  description = "Usuario de Docker Hub"
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Token/password de Docker Hub"
  type        = string
  sensitive   = true
}

variable "dockerhub_email" {
  description = "Email para el secret docker-registry"
  type        = string
}

variable "dockerhub_server" {
  description = "Servidor de Docker Hub"
  type        = string
  default     = "https://index.docker.io/v1/"
}

variable "qr_secret" {
  description = "Secret compartido para firma de tokens QR (prod — usar Vault o Secret Manager)"
  type        = string
  sensitive   = true
}
