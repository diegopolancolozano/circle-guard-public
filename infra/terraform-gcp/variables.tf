variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Region de GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona de GCP"
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "Nombre de la red VPC"
  type        = string
  default     = "circleguard-vpc"
}

variable "subnet_name" {
  description = "Nombre de la subred"
  type        = string
  default     = "circleguard-subnet"
}

variable "subnet_cidr" {
  description = "CIDR para la subred"
  type        = string
  default     = "10.20.0.0/24"
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

variable "allowed_ssh_cidrs" {
  description = "Rangos CIDR autorizados para SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "machines" {
  description = "Maquinas a crear en GCP"
  type = map(object({
    machine_type    = string
    disk_size_gb    = number
    tags            = list(string)
    startup_profile = string
  }))

  default = {
    jenkins = {
      machine_type    = "e2-standard-2"
      disk_size_gb    = 40
      tags            = ["ssh", "http", "jenkins"]
      startup_profile = "jenkins"
    }
    runner = {
      machine_type    = "e2-standard-2"
      disk_size_gb    = 30
      tags            = ["ssh", "runner"]
      startup_profile = "runner"
    }
  }
}
