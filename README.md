# gitops-demo — sample manifests for k8s-ui

Public demo GitOps repo. Mirrors the Argo CD “one record → AppProject +
Application + ServiceAccount” model on top of k8s-ui.

## Quick start — one command bootstrap

The whole demo spins up from **one** k8s-ui Application pointing at
`deploy/.helm`. The chart renders the workloads and emits two ConfigMaps that
k8s-ui materialises into child rows:

- `…-k8s-ui-child-projects` (label `k8s-ui.dev/projects: embedded`) →
  k8s-ui **Projects** (per-app `sourceRepos`, `destinations`,
  `clusterResourceWhitelist`)
- `…-k8s-ui-child-apps` (label `k8s-ui.dev/applications: embedded`) →
  k8s-ui **Applications**, each bound to the project of the same name

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
      "createNamespace": true,
      "materializeChildApps": true
    }
  }'
```

### Step 3 — what happens

On the first reconcile k8s-ui:

1. Renders the chart.
2. Applies inline workloads + per-app `Namespace` + `ServiceAccount`.
3. Reads the embedded projects ConfigMap → creates k8s-ui Projects.
4. Reads the embedded applications ConfigMap → creates k8s-ui Applications,
   each bound to its own project.

Each entry in `devApps` therefore produces **the same set of objects an Argo
CD `apps.yaml` template would**:

- `AppProject` (in k8s-ui terms — a `Project` row with policies)
- `Application`
- `ServiceAccount`

## `devApps` shape

Single map. Two flavours per entry:

| Has `source:` block | Has `inline: true` | Effect |
|---|---|---|
| ✅ | — | Application + Project + Namespace + ServiceAccount |
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

Project policies are derived automatically from the entry (`sourceRepos` =
`[source.repoUrl]`, `destinations` = the app's own cluster/namespace, plus
`Namespace + ClusterRoleBinding + PersistentVolume` whitelist). You can
override anything under a `project:` block:

```yaml
devApps:
  web:
    source: { repoUrl: …, path: …, targetRevision: main }
    destination: { namespace: gitops-demo }
    project:
      clusterWide: false
      clusterResourceWhitelist:
        - { group: "",                          kind: Namespace }
        - { group: "rbac.authorization.k8s.io", kind: ClusterRoleBinding }
        - { group: "policy",                    kind: PodDisruptionBudget }
      namespaceResourceBlacklist:
        - { group: "", kind: Secret }
```

## Repository layout

| Path | Renderer | What for |
|------|-----------|----------|
| `deploy/.helm`        | Helm — **parent/bootstrap** chart      | Emits embedded projects + embedded applications + per-app SA |
| `kubernetes`          | Plain YAML (recursive `.yaml`)         | Sample workload for the `web` Application |
| `samples/hello-world` | Helm (`helm template`)                 | Sample workload for the `hello-world` Application |
| `k8s-ui/apps.yaml`    | k8s-ui Apps Catalog (optional)         | Same parent app, declared in Git for catalog-driven setups |

## Render locally

```bash
helm template gitops-demo ./deploy/.helm
```

You'll see (for each Git-sourced entry): `Namespace`, `ServiceAccount`, plus
the two ConfigMaps consumed by k8s-ui's controller.
