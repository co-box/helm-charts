# eso-pw-generator

Reusable Helm chart that turns a list of secret names and keys into External Secrets Operator
[`Password` generators](https://external-secrets.io/latest/api/generator/password/) plus one
`ExternalSecret` per Secret. Nothing secret is ever rendered into git: the operator generates the
values in-cluster and writes a `Secret` into the release namespace.

The defaults are chosen so a GitOps sync never rotates a credential:

| Setting | Default | Why |
| --- | --- | --- |
| `target.immutable` | `true` | ESO (and Kubernetes) refuse to rewrite the data of an existing Secret. A re-sync, a pruned and re-applied `ExternalSecret`, or a changed generator spec leaves the value alone. |
| `target.creationPolicy` | `Orphan` | Deleting the `ExternalSecret` keeps the `Secret`. With `Owner`, Kubernetes GC deletes it too and the next sync generates a different value. |
| `refreshPolicy` | `OnChange` | No scheduled generator runs. On a spec/metadata change ESO reconciles, which lets it adopt pre-existing Secrets (drops stale owner references, sets `immutable`) without touching the data. `CreatedOnce` is stricter; `Periodic` would still not rotate while `immutable` is on, but runs the generators for nothing. |

## Usage

```yaml
# an Argo CD Application source
- repoURL: oci://ghcr.io/co-box/helm-charts/eso-pw-generator
  path: .
  targetRevision: 0.*
  helm:
    valuesObject:
      secrets:
        - name: my-app-secrets
          keys:
            - name: session-key
              length: 64
              # 64 random bytes, hex encoded (= 128 characters, no quotes/spaces)
              encoding: hex
              digits: 0
              noUpper: true
            - name: admin-password
              length: 32
              digits: 4
              symbols: 0
```

This renders:

- `Password/eso-pw-generator-my-app-secrets-session-key` and
  `Password/eso-pw-generator-my-app-secrets-admin-password` (prefix = release name),
- `ExternalSecret/my-app-secrets`, which writes `Secret/my-app-secrets` with keys `session-key`
  and `admin-password`.

All objects go to the release namespace, so with Argo CD's `destination.namespace` that is the
application's namespace. `sync-wave: -2` on the generators and `-1` on the `ExternalSecret` make the
Secret appear before workloads in wave 0.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `secrets` | `[]` | List of `{ name, keys, annotations?, refreshPolicy?, creationPolicy?, immutable? }`. |
| `secrets[].keys[]` | — | `{ name, length?, encoding?, digits?, symbols?, symbolCharacters?, noUpper?, allowRepeat?, prefix?, suffix? }`. |
| `defaults` | see `values.yaml` | Fallbacks for every key: `length`, `encoding`, `digits`, `symbols`, `noUpper`, `allowRepeat`. |
| `refreshPolicy` | `OnChange` | `CreatedOnce`, `OnChange` or `Periodic` for every `ExternalSecret`. |
| `creationPolicy` | `Orphan` | `Orphan` or `Owner`. Do not use `Owner` if values must survive a deleted `ExternalSecret`. |
| `immutable` | `true` | Freeze the generated Secret data. |
| `commonLabels`, `commonAnnotations` | `{}` | Added to every rendered object. |
| `fullnameOverride` | `""` | Prefix for generator names (default: the release name). |

Each key gets its own generator, so `length`/`encoding` can differ per key. Key names may contain
`-`, `_` and `.`; generator object names are normalised to lowercase DNS-1123.

## Rotating

With `immutable` + `Orphan`, ESO will neither overwrite nor recreate an existing Secret on its own.
To rotate, delete both objects and let Argo CD / ESO recreate them:

```bash
kubectl -n <namespace> delete secret <name> externalsecret <name>
```

If only the `Secret` is deleted, the `ExternalSecret` (marked `Orphan`) is considered valid and no
new value is generated; recreate the `ExternalSecret` as well (delete it, or let Argo CD recreate it).

## Requirements

- External Secrets Operator with the generator CRDs (`generators.external-secrets.io/v1alpha1`).
- The `Password` generator's `secretKeys` field (used to name each generated key).
