terraform {
  backend "gcs" {
    bucket = "circleguard-tfstate"
    prefix = "terraform-k8s/prod"
  }
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

data "kubernetes_namespace_v1" "env" {
  for_each = var.environments

  metadata {
    name = each.value
  }
}

module "docker_secret" {
  source = "../../modules/docker-secret"

  namespaces        = var.environments
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  dockerhub_email    = var.dockerhub_email
  dockerhub_server   = var.dockerhub_server
}
