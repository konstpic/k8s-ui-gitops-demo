# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo: Deployment, Service, Ingress, ConfigMap, Secret, ServiceAccount, Role, RoleBinding, PodDisruptionBudget, plus an **Application catalog** file for k8s-ui.

## Application catalog (`k8s-ui/apps.yaml`)

k8s-ui can **materialize Applications from Git**: the controller periodically reads a YAML file with an `applications:` list (same fields as the API: `name`, `project`, `source.repoUrl`, `source.path`, `source.targetRevision`, optional `source.helmValues`, `destination.cluster`, `destination.namespace`, optional `syncPolicy.automated`).

1. Register **Repositories** for every `source.repoUrl` in the file (this demo uses one URL three times).
2. Commit **`k8s-ui/apps.yaml`** in this repo (default path when `APPS_CATALOG_PATH` is unset).
3. On the **controller** process, set for example:

| Variable | Example |
|----------|---------|
| `APPS_CATALOG_REPO_URL` | `https://github.com/konstpic/k8s-ui-gitops-demo.git` |
| `APPS_CATALOG_PATH` | `k8s-ui/apps.yaml` (default) |
| `APPS_CATALOG_REVISION` | `main` or `HEAD` (default) |
| `APPS_CATALOG_INTERVAL` | `5m` (default; minimum `10s` when catalog is enabled) |

On each tick the controller **creates** missing rows and **updates** changed fields. Applications **removed** from the YAML are **not** deleted from the database (avoids wiping everything on a bad commit).

See also the k8s-ui project README section **Application catalog (Git-driven app list)**.

## `POST /api/v1/application-batches`

The JSON `template` is merged into each `items[]` row; each item may override **`repoUrl`**, **`path`**, **`targetRevision`**, **`cluster`**, **`destNamespace`**, **`project`**, and **`helmValues`** — useful for CI without relying on the catalog env vars.

## Use in k8s-ui (single Application per path)

| Path | Renderer | Typical destination namespace |
|------|-----------|----------------------------------|
| `kubernetes` | Plain YAML | `gitops-demo` (set in manifests) |
| `samples/hello-world` | Helm | e.g. `hello-world` |
| `deploy/.helm` | Helm (`devApps`, mostly `httpEcho`) | e.g. `gitops-demo-stack` (chart sets per-resource namespaces) |

**Revision:** branch or tag (e.g. `main`).

**Apply order:** k8s-ui sorts resources before apply (`Namespace` before `Deployment`, etc.); charts here also emit `Namespace` where useful.

## Ingress (optional)

`Ingress` uses host **`gitops-demo.local`**. Add to `/etc/hosts`:

```text
127.0.0.1 gitops-demo.local
```

Install an ingress controller (e.g. ingress-nginx) or delete `ingress.yaml` if you only use `kubectl port-forward` to the Service.

## Images

`kubernetes/` uses `nginxinc/nginx-unprivileged:1.27-alpine` (non-root). Sample Helm charts use `hashicorp/http-echo`.

## Chart `deploy/.helm` (devApps)

Helm values key **`devApps`** defines **`httpEcho`** components (Deployment + Service + Namespace per entry). Declarative **multi-repo** applications belong in **`k8s-ui/apps.yaml`** for the catalog, not in this chart.

```bash
helm template my-release ./deploy/.helm --namespace gitops-demo-stack
```
