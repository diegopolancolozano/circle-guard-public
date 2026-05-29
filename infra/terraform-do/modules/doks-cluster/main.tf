terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.42"
    }
  }
}

resource "digitalocean_kubernetes_cluster" "this" {
  name    = var.cluster_name
  region  = var.region
  version = var.k8s_version

  vpc_uuid = var.vpc_id != "" ? var.vpc_id : null
  tags     = var.tags

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count

    auto_scale = var.node_auto_scale
    min_nodes  = var.node_auto_scale ? var.node_min_count : null
    max_nodes  = var.node_auto_scale ? var.node_max_count : null

    tags   = var.node_tags
    labels = var.node_labels
  }
}
