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

## Deploy umbrella (Argo CD)

The `deploy/.helm` chart renders one **AppProject** + **Application** per entry in `devApps` (same idea as `argo-deploy2` / `020-devApps.yaml`, without Werf/Vault plugin env).

- **Argo app name:** `{umbrellaRelease}-{devAppKey}` (see `umbrellaRelease` in `deploy/.helm/values.yaml`).
- **Namespace:** defaults to the **devApp map key** (e.g. `demo-web` → namespace `demo-web`). Optional `namespacePrefix`, or set `namespace` on a single app.
- **Per app:** `repository`, `path`, `ref`, optional `enabled`, `syncPolicy`, `cluster`.
- **Test Helm app:** `samples/hello-world` — small chart (`hashicorp/http-echo`) that responds with **Hello World** on Service port 80; included in `devApps` as `hello-world` (namespace `hello-world`).

Render manifests:

```bash
helm template gitops-umbrella ./deploy/.helm
```

Point a parent Argo CD Application at this repo with path `deploy/.helm` and the same values (or layer env-specific values files).
