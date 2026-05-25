terraform {
  backend "gcs" {
    bucket = "circleguard-tfstate"
    prefix = "terraform-gcp/stage"
  }
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "vpc" {
  source = "../../modules/vpc"

  network_name        = "${var.network_name}-stage"
  subnet_name         = "${var.subnet_name}-stage"
  subnet_cidr         = var.subnet_cidr
  region              = var.region
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs
  enable_jenkins_firewall = var.enable_jenkins_firewall
}

module "compute" {
  source = "../../modules/compute"

  name_prefix   = "circleguard-stage"
  region        = var.region
  zone          = var.zone
  subnet_id     = module.vpc.subnet_id
  ssh_public_key = var.ssh_public_key
  ssh_user      = var.ssh_user
  machines      = var.machines
  environment   = "stage"
}
