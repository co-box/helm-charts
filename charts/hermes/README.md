# hermes

A generic [Hermes Agent](https://github.com/NousResearch/hermes-agent) chart: one stateful
instance with its own `$HERMES_HOME`, a dashboard/API service, an optional Ingress and optional
External Secrets generated credentials.

The chart renders:

| Resource | Purpose |
| --- | --- |
| `PersistentVolumeClaim` | `$HERMES_HOME` (`/opt/data`): `config.yaml`, `state.db`, skills, memories, workspace — the agent's memory |
| `ConfigMap` | Optional first-boot `config.yaml` (only when `config` is set) |
| `Deployment` | `gateway run` under the image's own s6 supervision, `strategy: Recreate` |
| `Service` | `dashboard` 9119 and `api` 8642 (ClusterIP by default) |
| `Ingress` | Optional, publishes the dashboard only |
| `ServiceAccount` | Optional, no API permissions |
| External Secrets objects | Optional: two `Password` generators plus an `ExternalSecret` for the API token and dashboard password |

## Usage

```bash
helm install hermes oci://ghcr.io/co-box/helm-charts/hermes --version 0.1.0 \
  --namespace hermes --create-namespace \
  --set existingSecret=hermes-env \
  --set ingress.enabled=true \
  --set ingress.host=hermes.example.com
```

`existingSecret` must contain the agent's environment (`API_SERVER_KEY`, the dashboard basic-auth
password, and any model provider key). With `credentials.generate=true` the chart creates it
instead, using External Secrets `Password` generators — see below.

### Config

`config` is the initial `config.yaml`. The `seed-config` init container copies it into the volume
only when no `config.yaml` exists, so `hermes config set` and dashboard changes always win. Set
`config: ""` to skip the ConfigMap and init container entirely.

```yaml
config: |
  model:
    default: deepseek-v4.1-flash
    provider: opencode-go
    base_url: https://opencode.ai/zen/go/v1
    api_mode: chat_completions
  agent:
    max_turns: 120
```

### Credentials

`credentials.generate=true` requires the External Secrets Operator. It renders:

- a `Password` generator of `credentials.apiServerKey.length` hex bytes → `API_SERVER_KEY`
- a `Password` generator of `credentials.dashboardPassword.length` raw alphanumerics →
  `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`
- an `ExternalSecret` named `existingSecret` with `refreshPolicy: OnChange`

The values are generated once when the objects are created; a periodic refresh does not rotate
them. Rotate deliberately by annotating the `ExternalSecret` and restarting the Deployment.

Credentials that cannot be generated (a model provider key belongs to the upstream account) can
be supplied through a second Secret with `extraEnvFrom`:

```yaml
existingSecret: hermes-env
extraEnvFrom:
  - secretRef:
      name: hermes-provider-key
```

### Values

See [`values.yaml`](values.yaml) for the full list. The most-used keys:

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `docker.io/nousresearch/hermes-agent` | Agent image |
| `image.tag` | `Chart.appVersion` | Image tag |
| `existingSecret` | `""` | Secret read via `envFrom` |
| `credentials.generate` | `false` | Generate `existingSecret` with ESO |
| `credentials.dashboardUsername` | `""` | Dashboard login name (not a credential) |
| `persistence.size` | `5Gi` | `$HERMES_HOME` size |
| `persistence.storageClass` | `""` | Cluster default; use a node-local class for SQLite's WAL |
| `service.dashboardPort` / `service.apiPort` | `9119` / `8642` | Service ports |
| `ingress.enabled` | `false` | Publish the dashboard |
| `ingress.host` | `""` | Required when the Ingress is enabled |
| `config` | `""` | Initial `config.yaml` |
| `hermes.uid` / `hermes.gid` | `1000` | uid/gid the image demotes to at boot |
| `timezone` | `Etc/UTC` | `TZ` for the agent |
| `shmSizeLimit` | `512Mi` | `/dev/shm`, sized for Chromium |

Do **not** set `runAsUser` in a pod security context: the image needs root for its boot-time
uid/gid remap and aborts on an arbitrary runtime user. It demotes itself via `HERMES_UID`/`HERMES_GID`.

## Publishing

The repo's GitHub Actions workflow packages and pushes every chart under `charts/` to
`ghcr.io/co-box/helm-charts/<chart-name>` on a push to `main`. Release a new chart version by
bumping `version` in `Chart.yaml`.
