variable "name_prefix" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
}

variable "region" {
  description = "Region de DigitalOcean (ej: nyc1, sfo3, lon1)"
  type        = string
}

variable "vpc_uuid" {
  description = "UUID de la VPC donde se desplegara el Droplet"
  type        = string
}

variable "droplet_size" {
  description = "Tamano del Droplet para Jenkins (ej: s-2vcpu-4gb)"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_public_key" {
  description = "Clave publica SSH en formato OpenSSH. Dejar vacio para omitir"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs que pueden conectarse por SSH al Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "environment" {
  description = "Nombre del ambiente (dev, stage, prod)"
  type        = string
  default     = "stage"
}
