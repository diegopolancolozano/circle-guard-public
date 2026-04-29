Kubernetes manifests (kustomize)

Usage:

# apply dev overlay
kubectl apply -k k8s/overlays/dev

# apply stage overlay
kubectl apply -k k8s/overlays/stage

# apply prod overlay
kubectl apply -k k8s/overlays/prod

Notes:
- Replace the image prefix TU_USUARIO_DOCKERHUB with your Docker Hub username.
- Secrets such as database credentials and qr-secret should be created/managed via `kubectl create secret` or a secret manager.
