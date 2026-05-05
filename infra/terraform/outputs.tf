output "managed_namespaces" {
  description = "Namespaces gestionados por Terraform"
  value       = sort([for ns in kubernetes_namespace_v1.env : ns.metadata[0].name])
}
