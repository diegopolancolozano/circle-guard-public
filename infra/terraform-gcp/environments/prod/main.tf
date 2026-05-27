terraform {
  backend "gcs" {
    bucket = "circleguard-tfstate"
    prefix = "terraform-gcp/prod"
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

  network_name            = "${var.network_name}-prod"
  subnet_name             = "${var.subnet_name}-prod"
  subnet_cidr             = var.subnet_cidr
  pods_cidr               = var.pods_cidr
  services_cidr           = var.services_cidr
  region                  = var.region
  allowed_ssh_cidrs       = var.allowed_ssh_cidrs
  enable_jenkins_firewall = var.enable_jenkins_firewall
}

module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_name        = var.gke_cluster_name
  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  environment         = "prod"

  node_count   = var.gke_node_count
  min_nodes    = var.gke_min_nodes
  max_nodes    = var.gke_max_nodes
  machine_type = var.gke_machine_type
  disk_size_gb = var.gke_disk_size_gb

  enable_private_nodes       = var.gke_enable_private_nodes
  master_ipv4_cidr_block     = var.gke_master_cidr
  master_authorized_networks = var.gke_master_authorized_networks
  deletion_protection        = true
}

resource "google_service_account" "jenkins" {
  account_id   = "circleguard-jenkins-prod"
  display_name = "CircleGuard Jenkins CI (prod)"
  project      = var.project_id
}

resource "google_project_iam_member" "jenkins_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                   = "circleguard-prod"
  region                        = var.region
  zone                          = var.zone
  subnet_id                     = module.vpc.subnet_id
  ssh_public_key                = var.ssh_public_key
  ssh_user                      = var.ssh_user
  machines                      = var.machines
  environment                   = "prod"
  jenkins_service_account_email = google_service_account.jenkins.email
}
