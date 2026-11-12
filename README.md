# GitOps Continuous Delivery with ArgoCD

Git is the single source of truth for what runs in the cluster. **ArgoCD**
watches a Git repository of Kubernetes manifests and continuously reconciles
the cluster with it: push a change to Git and the deployment updates itself —
no `kubectl apply` by hand. If someone changes the cluster manually, ArgoCD
detects the drift and heals it back to the Git state.

This project runs ArgoCD on a local 3-node [kind](https://kind.sigs.k8s.io/)
cluster. The demo application is a small nginx deployment whose manifests
live in this repository under `apps/my-app/` — ArgoCD syncs exactly that
path, so editing those files on GitHub *is* the deployment.

## Status

**In progress** — starter pack and manifests repository prepared; the
hands-on run (ArgoCD install, first sync, Git-change demo, drift test and
rollback) is being executed step by step on the cluster. This section is
updated as each stage is verified, and a "Verified run" section is added
only when the full verification passes.

## How it works

```
Developer ──► git push (this repo, apps/my-app/)
                    │
              ArgoCD polls the repo (~every 3 min)
                    │
                    ▼
        kind cluster ── my-app pods (auto-sync)
                    │
        ArgoCD UI: Synced / Healthy
        Mistake? ──► git revert ──► automatic rollback
```

- **Auto-sync** — ArgoCD applies new commits on its own (`automated` sync
  policy, with `prune` and `selfHeal` enabled).
- **Drift correction (selfHeal)** — a manual change in the cluster (for
  example `kubectl scale`) is detected as *OutOfSync* and reverted to the
  Git state automatically.
- **Rollback** — `git revert` of a bad commit; ArgoCD rolls the cluster
  back with it. The full history of "what ran, when" is the Git history.

## Layout

```
apps/my-app/            the demo app ArgoCD syncs (Deployment + Service)
argocd-application.yaml the ArgoCD Application (auto-sync, prune, selfHeal)
scripts/setup.sh        install ArgoCD on the cluster + apply the Application
verify.sh               six checks: ArgoCD pods, Application Synced/Healthy,
                        app pods, page reachable via NodePort
```

## Run it

```bash
bash scripts/setup.sh
# ArgoCD UI (separate terminal, leave it running):
kubectl port-forward svc/argocd-server -n argocd 8080:443
# open https://localhost:8080  (user: admin; password from
# argocd-initial-admin-secret — see setup output; self-signed cert
# warning in the browser is expected for a local lab)
bash verify.sh
```

The demo app is served on the cluster's host-mapped NodePort:
`http://localhost:30080`.

## The GitOps demo (the point of the project)

1. On GitHub, edit `apps/my-app/deployment.yaml`: replicas **2 → 4**,
   image **nginx:1.25 → nginx:1.27**, commit.
2. Within ~3 minutes (or press *Refresh* in the ArgoCD UI) the cluster
   scales to 4 pods on the new image — nobody ran `kubectl apply`.
3. Drift test: `kubectl scale deployment my-app -n gitops-demo --replicas=1`
   → ArgoCD shows *OutOfSync* and self-heals back to 4.
4. Rollback: `git revert` the commit on GitHub → the cluster returns to
   2 replicas / nginx:1.25.

## Author

Zain Ul Abdin — Zain Tech Automation Solutions
