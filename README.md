# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo: Deployment, Service, Ingress, ConfigMap, Secret, ServiceAccount, Role, RoleBinding, PodDisruptionBudget.

## Use in k8s-ui

- **Repository URL:** this repo’s HTTPS clone URL  
- **Path:** `kubernetes` (plain `.yaml` only; no Helm/Kustomize in MVP)  
- **Revision:** `main`  
- **Destination namespace:** manifests use namespace `gitops-demo` (set app destination to match, or rely on server default if your install overrides namespaces).

## Ingress (optional)

`Ingress` uses host **`gitops-demo.local`**. Add to `/etc/hosts`:

```text
127.0.0.1 gitops-demo.local
```

Install an ingress controller (e.g. ingress-nginx) or delete `ingress.yaml` if you only use `kubectl port-forward` to the Service.

## Images

Uses `nginxinc/nginx-unprivileged:1.27-alpine` (non-root).
