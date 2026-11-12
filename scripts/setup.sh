#!/usr/bin/env bash
# Setup: install ArgoCD on the existing kind cluster 'zaintech' and register
# the my-app Application from this repo. Run from anywhere: bash scripts/setup.sh
set -e
cd "$(dirname "$0")/.."

echo "== 1/4 Preflight: context, nodes, clock =="
kubectl config use-context kind-zaintech
kubectl get nodes
date

echo "== 2/4 Install ArgoCD =="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
if [ -f "$HOME/argocd-install.yaml" ]; then
  echo "using local manifest: ~/argocd-install.yaml"
  kubectl apply -n argocd -f "$HOME/argocd-install.yaml"
else
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "== 3/4 Wait for ArgoCD components =="
# Rollout status works on objects created by the apply above (a bare
# 'kubectl wait' on pods can error before the pods exist).
for d in argocd-server argocd-repo-server argocd-dex-server argocd-redis \
         argocd-applicationset-controller argocd-notifications-controller; do
  kubectl -n argocd rollout status deployment/$d --timeout=300s
done
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
kubectl get pods -n argocd

echo "== 4/4 Register the Application =="
kubectl apply -f argocd-application.yaml
kubectl get applications -n argocd

echo
echo "Done. ArgoCD UI (separate terminal, leave it running):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  open https://localhost:8080   (user: admin)"
echo "Admin password (do NOT screenshot it):"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "Demo app (after first sync):  http://localhost:30080"
