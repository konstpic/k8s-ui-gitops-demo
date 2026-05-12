# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo. Implements the Argo CD "app-of-apps" pattern on top
of k8s-ui using native `k8s-ui.io/v1alpha1` CRD objects.

## Quick start — one command bootstrap

The whole demo spins up from **one** k8s-ui Application pointing at
`deploy/.helm`. The chart renders inline workloads and emits
`k8s-ui.io/v1alpha1 AppProject` + `Application` objects for every Git-sourced
entry. The k8s-ui controller picks them up automatically on every reconcile —
no extra flag needed.

### Step 1 — register the repository

```
URL: https://github.com/konstpic/k8s-ui-gitops-demo.git
```

### Step 2 — create the parent Application (once)

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
    "destination": { "cluster": "in-cluster", "namespace": "gitops-demo-stack" },
    "syncPolicy": {
      "automated": { "prune": true, "selfHeal": true },
      "createNamespace": true
    }
  }'
```

### Step 3 — what happens

On the first reconcile k8s-ui:

1. Renders the chart.
2. Applies cluster resources: inline workloads + per-app `Namespace` +
   `ServiceAccount`.
3. Recognises `k8s-ui.io/v1alpha1 AppProject` objects in rendered manifests →
   creates k8s-ui Projects (per-app `sourceRepos`, `destinations`).
4. Recognises `k8s-ui.io/v1alpha1 Application` objects → creates k8s-ui
   Applications, each bound to its own project.
5. The child Applications are NOT applied to the cluster — they are
   control-plane declarations handled only by k8s-ui.

Each entry in `devApps` therefore produces **the same set of objects an Argo
CD app-of-apps template would**:

- `AppProject` (rendered as `k8s-ui.io/v1alpha1` → k8s-ui `Project` row)
- `Application` (rendered as `k8s-ui.io/v1alpha1` → k8s-ui `Application` row)
- `Namespace` + `ServiceAccount` (applied to the cluster)

## `devApps` shape

Single map. Two flavours per entry:

| Has `source:` block | Has `inline: true` | Effect |
|---|---|---|
| ✅ | — | AppProject + Application child objects + Namespace + ServiceAccount |
| — | ✅ | Direct `Deployment` + `Service` + `Namespace` (httpEcho) |

```yaml
devApps:
  web:
    source:
      repoUrl: https://github.com/konstpic/k8s-ui-gitops-demo.git
      path: kubernetes
      targetRevision: main
    destination:
      namespace: gitops-demo
    syncPolicy:
      automated: { prune: true, selfHeal: true }
      createNamespace: true

  hello-echo:
    inline: true
    message: "Hello World"
    image: { repository: hashicorp/http-echo, tag: "0.2.3" }
```

The rendered child Application objects look like:

```yaml
apiVersion: k8s-ui.io/v1alpha1
kind: AppProject
metadata:
  name: web
spec:
  sourceRepos:
    - "https://github.com/konstpic/k8s-ui-gitops-demo.git"
  destinations:
    - name: "in-cluster"
      namespace: "gitops-demo"
---
apiVersion: k8s-ui.io/v1alpha1
kind: Application
metadata:
  name: web
spec:
  project: web
  source:
    repoURL: "https://github.com/konstpic/k8s-ui-gitops-demo.git"
    path: "kubernetes"
    targetRevision: "main"
  destination:
    name: "in-cluster"
    namespace: "gitops-demo"
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    createNamespace: true
```

## Repository layout

| Path | Renderer | What for |
|------|-----------|----------|
| `deploy/.helm`        | Helm — **parent/bootstrap** chart      | Emits AppProject + Application child objects + per-app SA |
| `kubernetes`          | Plain YAML (recursive `.yaml`)         | Sample workload for the `web` Application |
| `samples/hello-world` | Helm (`helm template`)                 | Sample workload for the `hello-world` Application |
| `k8s-ui/apps.yaml`    | k8s-ui Apps Catalog (optional)         | Parent app declared in CRD format for catalog-driven setups |

## Render locally

```bash
helm template gitops-demo ./deploy/.helm
```

You'll see for each Git-sourced entry: `Namespace`, `ServiceAccount`,
`k8s-ui.io/v1alpha1 AppProject`, and `k8s-ui.io/v1alpha1 Application`.
The controller filters out the AppProject/Application objects before apply —
only the Namespace and ServiceAccount reach the cluster.
