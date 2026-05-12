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

**k8s-ui sync ordering:** the control plane applies `Namespace` (and other
RBAC-ish kinds) before `Deployment` even when plain YAML files are listed
alphabetically (`deployment.yaml` before `namespace.yaml`). The umbrella chart
creates a `Namespace` for each `httpEcho` target namespace; the
`samples/hello-world` chart optionally renders its destination namespace
(`createNamespace`, default `true`).

## Ingress (optional)

`Ingress` uses host **`gitops-demo.local`**. Add to `/etc/hosts`:

```text
127.0.0.1 gitops-demo.local
```

Install an ingress controller (e.g. ingress-nginx) or delete `ingress.yaml` if you only use `kubectl port-forward` to the Service.

## Images

Uses `nginxinc/nginx-unprivileged:1.27-alpine` (non-root) in `kubernetes/`. The devApps chart and `samples/hello-world` use `hashicorp/http-echo` for a minimal HTTP response.

## Chart `deploy/.helm` (devApps)

One k8s-ui **Application** points at path **`deploy/.helm`** (Helm). Values key **`devApps`** lists logical components. Supported **`type`** values:

| `type` | What gets rendered into the cluster |
|--------|-------------------------------------|
| **`httpEcho`** | `Deployment` + `Service` (synthetic echo pod). Namespace defaults to the map key unless you set **`namespace`**. |
| **`gitHelmSource`** | No Pod from this chart alone. Emits a **ConfigMap** (`…-desired-applications`) whose `data` entries are small YAML documents shaped like **`POST /api/v1/applications`** bodies: `name`, `project`, `source.repoUrl`, `source.path`, `source.targetRevision`, `destination.cluster`, `destination.namespace`, `syncPolicy`. One Git repo + one chart path per entry — exactly one k8s-ui Application per child. |

**Git + Helm for children:** register each **`repository`** URL under **Repositories** in the UI (or API), then create one Application per `gitHelmSource` row (same fields as in the ConfigMap). The ConfigMap is the **declarative list** you can drive from CI (read keys `desired-*.application.yaml`, `POST` each payload) until the product grows a built-in importer or reconciler for that object.

**`POST /api/v1/application-batches`** today uses one shared **template** (single `repoUrl` / `path` / `revision`) for all batch rows, so it does **not** replace per-repo batching; use one `POST /applications` per distinct source, or a small script over the ConfigMap.

**Parent sync** applies the ConfigMap plus any **`httpEcho`** workloads in one revision; child charts are still rendered by **their own** Application when you add them in the control plane.

Other details:

- **Object names** for `httpEcho` use the Helm release name (k8s-ui Application name), e.g. `my-release-hello-echo`.
- Optional **`helmValues`** on the parent Application is merged into `helm template` as an extra values file.

Render locally:

```bash
helm template my-release ./deploy/.helm --namespace gitops-system
```

The **`kubernetes/`** nginx demo remains a good **separate** Application (plain YAML). You can also point a standalone Application at **`samples/hello-world`** without listing it under `gitHelmSource`, if you prefer not to duplicate that chart in GitOps metadata.
