terraform {
  backend "s3" {}
  required_version = ">= 1.6.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.42"
    }
  }
}

provider "digitalocean" {}

module "vpc" {
  source = "../../modules/vpc"

  name        = var.vpc_name
  region      = var.region
  ip_range    = var.vpc_ip_range
  description = "CircleGuard stage VPC"
}

module "doks" {
  source = "../../modules/doks-cluster"

  cluster_name   = var.cluster_name
  region         = var.region
  k8s_version    = var.k8s_version
  vpc_id         = module.vpc.vpc_id
  tags           = var.tags
  node_pool_name = var.node_pool_name
  node_size      = var.node_size
  node_count     = var.node_count
  node_auto_scale = var.node_auto_scale
  node_min_count = var.node_min_count
  node_max_count = var.node_max_count
  node_tags      = var.node_tags
  node_labels    = var.node_labels
}

output "cluster_name" {
  value = module.doks.cluster_name
}

output "cluster_endpoint" {
  value = module.doks.cluster_endpoint
}

output "kubeconfig_raw" {
  value     = module.doks.kubeconfig_raw
  sensitive = true
}
