output "vm_public_ips" {
  description = "IP publica por VM"
  value = {
    for name, addr in google_compute_address.vm_ip :
    name => addr.address
  }
}

output "ssh_commands" {
  description = "Comandos SSH sugeridos por VM"
  value = {
    for name, vm in google_compute_instance.vm :
    name => "ssh ${var.ssh_user}@${vm.network_interface[0].access_config[0].nat_ip}"
  }
}

output "jenkins_url" {
  description = "URL de Jenkins (si existe VM jenkins)"
  value       = contains(keys(google_compute_instance.vm), "jenkins") ? "http://${google_compute_instance.vm["jenkins"].network_interface[0].access_config[0].nat_ip}:8080" : null
}
