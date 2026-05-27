output "network_id" {
  description = "ID de la red VPC"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "Nombre de la red VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "ID de la subred"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "Nombre de la subred"
  value       = google_compute_subnetwork.subnet.name
}

output "pods_range_name" {
  description = "Nombre del rango secundario para Pods de GKE"
  value       = "${var.subnet_name}-pods"
}

output "services_range_name" {
  description = "Nombre del rango secundario para Services de GKE"
  value       = "${var.subnet_name}-services"
}
