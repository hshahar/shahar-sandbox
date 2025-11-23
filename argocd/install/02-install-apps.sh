#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=argocd

echo "Installing ArgoCD Applications (App-of-Apps pattern)..."
helm upgrade --install argocd-apps argo/argocd-apps \
  --namespace "$NAMESPACE" \
  -f 03-values-apps.yaml

echo ""
echo "Waiting for applications to be created..."
sleep 5

echo ""
echo "Checking Applications and AppProjects..."
kubectl -n "$NAMESPACE" get app,appproject

echo ""
echo "ArgoCD Apps installed successfully!"
echo "The root app will automatically sync child applications from: argocd/applications/"
