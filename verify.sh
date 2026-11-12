#!/usr/bin/env bash
# Verification for the ArgoCD GitOps project. Prints Passed/Failed counts.
PASS=0; FAIL=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

echo "== ArgoCD GitOps verification =="

# 1. All ArgoCD pods Running and Ready
NOTREADY=$(kubectl -n argocd get pods --no-headers 2>/dev/null | grep -vc "Running" || true)
TOTAL=$(kubectl -n argocd get pods --no-headers 2>/dev/null | wc -l)
if [ "$TOTAL" -gt 0 ] && [ "$NOTREADY" -eq 0 ]; then
  ok "ArgoCD pods all Running ($TOTAL pods)"
else
  bad "ArgoCD pods not all Running ($NOTREADY of $TOTAL)"
fi

# 2. Application exists
if kubectl -n argocd get application my-app >/dev/null 2>&1; then
  ok "Application my-app exists"
else
  bad "Application my-app missing"
fi

# 3. Application Synced
SYNC=$(kubectl -n argocd get application my-app -o jsonpath='{.status.sync.status}' 2>/dev/null)
[ "$SYNC" = "Synced" ] && ok "Application sync status = Synced" || bad "Application sync status = $SYNC (want Synced)"

# 4. Application Healthy
HEALTH=$(kubectl -n argocd get application my-app -o jsonpath='{.status.health.status}' 2>/dev/null)
[ "$HEALTH" = "Healthy" ] && ok "Application health = Healthy" || bad "Application health = $HEALTH (want Healthy)"

# 5. App pods match the replica count written in Git
WANT=$(grep -E '^\s*replicas:' apps/my-app/deployment.yaml | awk '{print $2}')
RUNNING=$(kubectl -n gitops-demo get pods -l app=my-app --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$RUNNING" = "$WANT" ]; then
  ok "my-app pods Running = $RUNNING (matches Git replicas: $WANT)"
else
  bad "my-app pods Running = $RUNNING (Git replicas: $WANT)"
fi

# 6. App page reachable on the host-mapped NodePort
if curl -s -o /dev/null -w "%{http_code}" http://localhost:30080 | grep -q "200"; then
  ok "nginx welcome page reachable at http://localhost:30080"
else
  bad "no 200 from http://localhost:30080"
fi

echo
echo "Passed: $PASS / Failed: $FAIL"
