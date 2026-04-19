# ivlholding/.github

Org-wide GitHub configuration and **reusable workflows** for all `ivlholding/*` repos.

## Reusable workflows

Each workflow lives under `.github/workflows/` and is callable via `workflow_call`:

| Workflow | Purpose | Typical caller |
|---|---|---|
| `go-ci.yml` | Lint + unit tests + build for any Go module | every Go repo on PR/push |
| `go-integration.yml` | Bring up a docker-compose stack and run `-tags=integration` tests | repos with integration tests |
| `image-build.yml` | Build + Trivy scan + Cosign sign + push to Zot | on tag `v*` |
| `proto-regen.yml` | Validate `buf generate` output is up-to-date | `scraper-apis` |

## Usage

```yaml
# .github/workflows/ci.yml in any ivlholding/* repo
name: CI
on: [push, pull_request]
jobs:
  ci:
    uses: ivlholding/.github/.github/workflows/go-ci.yml@main
    with:
      go-version: "1.25"
```

## Conventions

- All reusable workflows accept `go-version` as optional input (default: `1.25`).
- Secrets are passed via `secrets: inherit` from the caller.
- Self-hosted runner label: `self-hosted`. Override per-repo via `runner` input if needed.
