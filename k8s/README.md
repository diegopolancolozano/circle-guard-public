Kubernetes manifests (kustomize)

Usage:

# apply dev overlay
kubectl apply -k k8s/overlays/dev

# apply stage overlay
kubectl apply -k k8s/overlays/stage

# apply master overlay
kubectl apply -k k8s/overlays/master

Notes:
- The base overlay deploys the six selected services: auth, identity, promotion, gateway, dashboard, and file.
- Secrets such as database credentials and `qr-secret` are defined in the base manifests for local development.
