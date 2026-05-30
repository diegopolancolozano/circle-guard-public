output "secret_names" {
  description = "Nombres de los secrets creados por namespace"
  value = {
    for ns, secret in kubernetes_secret_v1.dockerhub_pull_secret :
    ns => secret.metadata[0].name
  }
}
