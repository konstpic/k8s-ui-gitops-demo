# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo: Deployment, Service, Ingress, ConfigMap, Secret, ServiceAccount, Role, RoleBinding, PodDisruptionBudget.

## Use in k8s-ui

Register this repository, then create **Applications** (each sync runs `git clone` + render + apply):

| Path | Renderer | Destination namespace (typical) |
|------|-----------|-----------------------------------|
| `kubernetes` | Plain YAML (recursive `.yaml`) | `gitops-demo` (namespaces are set in the files) |
| `samples/hello-world` | Helm (`helm template`) | e.g. `hello-world` (chart leaves namespace empty; k8s-ui fills from Application destination) |
| `deploy/.helm` | Helm — **devApps** chart (see below) | Any; chart sets explicit `metadata.namespace` per entry (default = map key, e.g. `hello-world`) |

**Revision:** your branch or tag (e.g. `main`).

## Ingress (optional)

`Ingress` uses host **`gitops-demo.local`**. Add to `/etc/hosts`:

```text
127.0.0.1 gitops-demo.local
```

Install an ingress controller (e.g. ingress-nginx) or delete `ingress.yaml` if you only use `kubectl port-forward` to the Service.

## Images

Uses `nginxinc/nginx-unprivileged:1.27-alpine` (non-root) in `kubernetes/`. The devApps chart and `samples/hello-world` use `hashicorp/http-echo` for a minimal HTTP response.

## Chart `deploy/.helm` (devApps)

One k8s-ui **Application** with path **`deploy/.helm`** runs a single Helm release. Values key **`devApps`** describes several logical components; the chart renders normal **Deployment** and **Service** objects (currently type **`httpEcho`** only).

- **Namespace** for each entry defaults to the **map key** (e.g. `hello-world` → namespace `hello-world`). Optional **`namespacePrefix`** in values, or **`namespace`** on one entry.
- **Object names** include the Helm release name (k8s-ui Application name), e.g. `my-release-hello-world`.
- Optional per-app **`helmValues`** in the API is merged as an extra `-f` file if you need overrides without committing them.

Render locally:

```bash
helm template my-release ./deploy/.helm
```

The **`kubernetes/`** nginx demo and **`samples/hello-world`** stay useful as **separate** Applications when you want a different layout or a standalone chart without the devApps values file.
