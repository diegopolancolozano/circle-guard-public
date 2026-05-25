output "cluster_id" {
  description = "ID del cluster"
  value       = digitalocean_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Nombre del cluster"
  value       = digitalocean_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint del API server"
  value       = digitalocean_kubernetes_cluster.this.endpoint
}

output "kubeconfig_raw" {
  description = "Kubeconfig raw del cluster"
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].raw_config
  sensitive   = true
}
