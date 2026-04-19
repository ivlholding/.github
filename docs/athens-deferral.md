# Athens private Go module proxy — deferred

**Status:** Deferred indefinitely. Revisit when any of these become true:
- ≥3 private ivlholding modules consumed cross-repo (currently 1: scraper-core).
- CI `go mod download` against github.com exceeds 60s wall-clock or hits
  GitHub's anonymous rate-limit in any failure mode.
- Multiple isolated networks need the same modules without reaching github.com.

## Why not now

- One consumer (scraper-ricardo) pulling one module (scraper-core).
- Direct GitHub HTTPS with App-token auth is ~2s for `go mod download`
  in CI — no proxy would improve this.
- Athens adds a service, a MinIO bucket, a backup regime, a TLS cert, and
  an upgrade treadmill. Too much weight for current scale.

## If we stand it up later

Target: `scraper-infra/stacks/infra.yml.tmpl`. Service sketch:

```yaml
athens:
  image: gomods/athens:v0.14
  networks: [scraper-internal]
  environment:
    - ATHENS_STORAGE_TYPE=s3
    - ATHENS_S3_ENDPOINT=minio:9000
    - ATHENS_S3_BUCKET=athens-cache
    - ATHENS_DOWNLOAD_MODE=async_redirect
    - ATHENS_GITHUB_TOKEN_FILE=/run/secrets/github_modules_token
  secrets: [github_modules_token]
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:3000/healthz"]
```

Bucket `athens-cache` added to `minio-bootstrap.sh` with a 365d ILM policy.

Caller CI reuses `go-ci.yml` with `GOPROXY=https://athens.internal,direct`
injected via a new `module-proxy` input.

## Verification plan (for when we do this)

1. Warm cache: on a fresh runner, `go mod download` for scraper-ricardo
   hits Athens (log shows `GET /github.com/ivlholding/scraper-core/@v/v0.1.0.zip`).
2. Sever GitHub outbound firewall rule → `go mod download` still succeeds
   from cache.
3. Tag a new v0.1.1 of scraper-core → Athens async_redirect fetches within 60s.
