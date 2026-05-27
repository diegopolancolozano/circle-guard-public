variable "name_prefix" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "region" {
  description = "Region de GCP"
  type        = string
}

variable "zone" {
  description = "Zona de GCP"
  type        = string
}

variable "subnet_id" {
  description = "ID de la subred donde conectar las VMs"
  type        = string
}

variable "ssh_public_key" {
  description = "Clave publica SSH en formato OpenSSH"
  type        = string
}

variable "ssh_user" {
  description = "Usuario Linux usado por SSH"
  type        = string
  default     = "deployer"
}

variable "machines" {
  description = "Maquinas a crear en GCP"
  type = map(object({
    machine_type    = string
    disk_size_gb    = number
    tags            = list(string)
    startup_profile = string
  }))
}

variable "environment" {
  description = "Nombre del ambiente (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "jenkins_service_account_email" {
  description = "Email de la service account para el Jenkins VM (necesario para kubectl / gcloud)"
  type        = string
  default     = ""
}
