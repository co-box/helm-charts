# Helm charts

Collection of various helm-charts, published to `ghcr.io/co-box/helm-charts/<chart>`.

## Automated version updates

`.github/workflows/renovate.yaml` runs [Renovate](https://docs.renovatebot.com/) daily (and on
manual dispatch) with the rules in [`renovate.json`](renovate.json). Only the two chart/application
pairs below are managed; the custom regex managers exist because the chart version, `appVersion`
and image tag have to move together.

| Chart | Upstream | Renovate updates |
| --- | --- | --- |
| `hermes` | `docker.io/nousresearch/hermes-agent` | `Chart.yaml` `version` + `appVersion`; the default image tag follows `appVersion` |
| `glitchtip-bootstrap` | `docker.io/glitchtip/glitchtip` | `values.yaml` `image.tag` + `Chart.yaml` `version` + `appVersion` |

Merging a Renovate PR changes `charts/**`, so the release workflow publishes the new chart version
automatically. Only release tags are considered: Hermes `v0.Y.Z` on the current `0.x` line (not the
old calendar `v2026.*` tags, `-desktop`/arch builds or `canary`), GlitchTip `X.Y.Z` (not `latest`,
short `7`/`7.0` aliases or arch tags).

### Required secret

Create a fine-grained PAT with **Contents: read/write**, **Pull requests: read/write**,
**Issues: read/write** and **Metadata: read** on this repository, then store it as the Actions
secret `RENOVATE_TOKEN`. The default `GITHUB_TOKEN` is not used because this repository does not
allow GitHub Actions to create pull requests.
