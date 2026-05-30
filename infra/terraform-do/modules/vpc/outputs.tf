output "vpc_id" {
  description = "ID de la VPC"
  value       = digitalocean_vpc.this.id
}

output "vpc_name" {
  description = "Nombre de la VPC"
  value       = digitalocean_vpc.this.name
}

output "vpc_region" {
  description = "Region de la VPC"
  value       = digitalocean_vpc.this.region
}
