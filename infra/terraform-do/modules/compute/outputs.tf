output "jenkins_ip" {
  description = "IP publica reservada del Droplet Jenkins"
  value       = digitalocean_reserved_ip.jenkins.ip_address
}

output "jenkins_url" {
  description = "URL de la interfaz web de Jenkins"
  value       = "http://${digitalocean_reserved_ip.jenkins.ip_address}:8080"
}

output "ssh_command" {
  description = "Comando SSH para conectarse al Droplet Jenkins"
  value       = "ssh root@${digitalocean_reserved_ip.jenkins.ip_address}"
}

output "droplet_id" {
  description = "ID del Droplet Jenkins"
  value       = digitalocean_droplet.jenkins.id
}
