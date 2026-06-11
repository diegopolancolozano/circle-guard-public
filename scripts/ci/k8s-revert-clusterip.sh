#!/usr/bin/env bash
# Revierte servicios de demo de LoadBalancer → ClusterIP para que DO elimine los LBs.
# Uso: k8s-revert-clusterip.sh [namespace]   (default: stage)
set -euo pipefail

NS="${1:-stage}"

patch_clusterip() {
    local ns=$1 svc=$2 port=$3
    kubectl -n "$ns" patch svc "$svc" \
        -p "{\"spec\":{\"type\":\"ClusterIP\",\"ports\":[{\"port\":${port},\"targetPort\":${port},\"protocol\":\"TCP\"}]}}" \
        2>/dev/null \
        && echo "  OK  $ns/$svc → ClusterIP:${port}" \
        || echo "  SKIP $ns/$svc"
}

echo "=== Revirtiendo servicios de ${NS} → ClusterIP ==="
patch_clusterip "$NS" circleguard-auth-service       8080
patch_clusterip "$NS" circleguard-identity-service   8080
patch_clusterip "$NS" circleguard-promotion-service  8081
patch_clusterip "$NS" circleguard-gateway-service    8080
patch_clusterip "$NS" circleguard-dashboard-service  8080
patch_clusterip "$NS" circleguard-file-service       8080

echo "=== Revirtiendo servicios de monitoring → ClusterIP ==="
patch_clusterip monitoring grafana    3000
patch_clusterip monitoring prometheus 9090

echo "Servicios revertidos. DO eliminará los LBs en ~1 min."
