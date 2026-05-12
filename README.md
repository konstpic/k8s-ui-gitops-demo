# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo: Deployment, Service, Ingress, ConfigMap, Secret, ServiceAccount, Role, RoleBinding, PodDisruptionBudget.

## Quick start — one command bootstrap

The whole demo spins up from **a single k8s-ui Application** that points at
`deploy/.helm`. It renders the chart, applies the workloads, and automatically
creates all child Applications via `materializeChildApps`.

### Step 1 — register the repository

In the k8s-ui UI (or API) add:

```
URL: https://github.com/konstpic/k8s-ui-gitops-demo.git
```

No credentials needed for a public repo.

### Step 2 — create the parent Application (once)

Via the UI or with curl:

```bash
curl -X POST http://localhost:8080/api/v1/applications \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "gitops-demo-stack",
    "project": "default",
    "source": {
      "repoUrl": "https://github.com/konstpic/k8s-ui-gitops-demo.git",
      "path": "deploy/.helm",
      "targetRevision": "main"
    },
    "destination": {
      "cluster": "in-cluster",
      "namespace": "gitops-demo-stack"
    },
    "syncPolicy": {
      "automated": { "prune": true, "selfHeal": true },
      "createNamespace": true,
      "materializeChildApps": true
    }
  }'
```

### Step 3 — done

After the first sync k8s-ui reads the `childApplications` list from the
rendered ConfigMap in `deploy/.helm/templates/desired-applications-configmap.yaml`
and upserts the child Application rows automatically:

- **gitops-demo-web** — nginx demo (`kubernetes/`)
- **gitops-demo-hello-world** — Helm sample (`samples/hello-world`)

All children have `automated.prune=true, selfHeal=true` so they stay in sync
without manual intervention.

To add a new child application, add an entry to `childApplications` in
`deploy/.helm/values.yaml`, commit, and push. The parent auto-syncs within the
configured interval and the new Application row appears in k8s-ui.

---

## Repository layout

| Path | Renderer | Destination namespace (typical) |
|------|-----------|-----------------------------------|
| `kubernetes` | Plain YAML (recursive `.yaml`) | `gitops-demo` (namespaces are set in the files) |
| `samples/hello-world` | Helm (`helm template`) | `hello-world` |
| `deploy/.helm` | Helm — **parent/bootstrap** chart | `gitops-demo-stack` |

**Revision:** your branch or tag (e.g. `main`).

## Application catalog (`k8s-ui/apps.yaml`)

This repo includes **`k8s-ui/apps.yaml`**, which declares several k8s-ui Applications
(`gitops-demo-web`, `gitops-demo-hello-world`, `gitops-demo-devapps`). They are
**created only if** the k8s-ui controller has the catalog enabled:

1. Register the repo in k8s-ui with URL **`https://github.com/konstpic/k8s-ui-gitops-demo.git`**
   (must match every `source.repoUrl` in the file **exactly**).
2. Set **`APPS_CATALOG_REPO_URL`** to that same URL (or use Helm: `appsCatalog.enabled=true`
   and `appsCatalog.repoUrl=...` in the [k8s-ui `deploy/helm` chart](https://github.com/konstpic/k8s-ui/tree/main/deploy/helm)).
3. Restart / upgrade so the process sees the env vars. Check controller logs for
   `apps catalog: created application` or `apps catalog: bad entry` / `read file` warnings.

Without `APPS_CATALOG_REPO_URL`, the file in Git is ignored.

### Parent chart + embedded child list (`deploy/.helm`)

Alternatively (or in addition), enable **`syncPolicy.materializeChildApps: true`**
on a single k8s-ui Application that points at **`deploy/.helm`**. The chart can
emit a ConfigMap (`values.childApplications` → `templates/desired-applications-configmap.yaml`)
labeled **`k8s-ui.dev/applications: embedded`**. On each reconcile, k8s-ui
reads the rendered `applications:` YAML and **creates/updates** those child
Application rows in the database (repos must still be registered).

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
