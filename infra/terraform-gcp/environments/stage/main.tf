terraform {
  backend "gcs" {}  # bucket/prefix passed via -backend-config in gcp-provision.sh
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

# ---------------------------------------------------------------------------
# VPC + secondary ranges for GKE
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  network_name            = "${var.network_name}-stage"
  subnet_name             = "${var.subnet_name}-stage"
  subnet_cidr             = var.subnet_cidr
  pods_cidr               = var.pods_cidr
  services_cidr           = var.services_cidr
  region                  = var.region
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
  enable_jenkins_firewall = var.enable_jenkins_firewall
}

# ---------------------------------------------------------------------------
# GKE cluster (Standard, regional, VPC-native)
# ---------------------------------------------------------------------------
module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_name        = var.gke_cluster_name
  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  environment         = "stage"

  node_count   = var.gke_node_count
  min_nodes    = var.gke_min_nodes
  max_nodes    = var.gke_max_nodes
  machine_type = var.gke_machine_type
  disk_size_gb = var.gke_disk_size_gb

  enable_private_nodes       = var.gke_enable_private_nodes
  master_ipv4_cidr_block     = var.gke_master_cidr
  master_authorized_networks = var.gke_master_authorized_networks
  deletion_protection        = false
}

# ---------------------------------------------------------------------------
# Jenkins service account — creado para referencia futura
# Los IAM bindings se omiten: requieren roles/resourcemanager.projectIamAdmin
# que no está disponible en el SA de Terraform de este proyecto.
# ---------------------------------------------------------------------------
resource "google_service_account" "jenkins" {
  account_id   = "circleguard-jenkins-stage"
  display_name = "CircleGuard Jenkins CI (stage)"
  project      = var.project_id
}

# ---------------------------------------------------------------------------
# VMs: Jenkins controller + optional runner
# ---------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  name_prefix                   = "circleguard-stage"
  region                        = var.region
  zone                          = var.zone
  subnet_id                     = module.vpc.subnet_id
  ssh_public_key                = var.ssh_public_key
  ssh_user                      = var.ssh_user
  machines                      = var.machines
  environment                   = "stage"
  jenkins_service_account_email = google_service_account.jenkins.email
}
