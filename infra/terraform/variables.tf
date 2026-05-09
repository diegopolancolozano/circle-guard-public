variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig que usara Terraform"
  type        = string
}

variable "use_gke" {
  description = "Cuando es true, configura el provider kubernetes usando GKE (data.google_container_cluster). Si es false, usa `kubeconfig_path`."
  type        = bool
  default     = false
}

variable "gcp_project" {
  description = "ID del proyecto GCP (usado cuando use_gke = true)"
  type        = string
  default     = ""
}

variable "gke_cluster_name" {
  description = "Nombre del cluster GKE (usado cuando use_gke = true)"
  type        = string
  default     = ""
}

variable "gke_cluster_location" {
  description = "Zona o region del cluster GKE (usado cuando use_gke = true)"
  type        = string
  default     = ""
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
  description = "Secret compartido usado por gateway/auth"
  type        = string
  sensitive   = true
}

variable "environments" {
  description = "Namespaces de despliegue"
  type        = set(string)
  default     = ["dev", "stage", "prod"]
}
