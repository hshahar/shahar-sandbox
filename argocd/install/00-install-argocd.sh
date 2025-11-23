#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=argocd

echo "Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "Installing Argo CD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f 01-values-argocd.yaml

echo "Waiting for Argo CD to be ready..."
kubectl -n "$NAMESPACE" rollout status deploy/argocd-server --timeout=600s

echo ""
echo "Argo CD installed successfully!"
echo ""
echo "Getting pods status..."
kubectl -n "$NAMESPACE" get pods -o wide

echo ""
echo "Getting initial admin password..."
kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access Argo CD at: http://sha-argocd.blog.local"
echo "Username: admin"
echo "Password: (shown above)"
