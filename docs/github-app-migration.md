# Migrating private-module auth: PAT → GitHub App

Current state: scraper-ricardo's CI fetches scraper-core via a fine-grained PAT
(`IVL_MODULES_TOKEN`). This works but has two ergonomic problems:

1. **PAT expiry.** Max 1-year lifetime, then quiet CI failures until rotated.
2. **User-scoped.** Tied to one human. They leave the org, everything breaks.

A GitHub App is the right long-term answer: installation-scoped, auto-renewing
tokens, narrower blast radius, auditable in org logs.

## One-time App creation

1. Org owner → **Settings → Developer settings → GitHub Apps → New App**.
2. Name: `ivl-ci-modules`. Homepage: `https://github.com/ivlholding`.
3. Uncheck **Webhook** (not needed for CI).
4. **Repository permissions:**
   - Contents: Read
   - Metadata: Read (auto)
   - Actions: Read (if you want cross-repo workflow-run queries later)
5. **Subscribe to events:** none.
6. **Where can this app be installed:** Only on this account.
7. Create → on the App page, **Generate a private key** → save the `.pem`.
8. Note the **App ID** (6-digit number at top of the App page).
9. **Install App** → pick the ivlholding org → grant access to the repos that
   need cross-repo module resolution (currently just scraper-ricardo, but
   scoping to "All repositories" is cleaner for new additions).

## Wiring the App into workflows

Save as **org-level** secrets at ivlholding → Settings → Secrets → Actions:
- `IVL_CI_APP_ID`
- `IVL_CI_APP_PRIVATE_KEY` (entire contents of the `.pem`)

Then `.github/workflows/go-ci.yml` gains an optional branch:

```yaml
- name: Mint App token
  if: inputs.private-modules && secrets.IVL_CI_APP_ID != ''
  id: app
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.IVL_CI_APP_ID }}
    private-key: ${{ secrets.IVL_CI_APP_PRIVATE_KEY }}
    owner: ivlholding

- name: Configure private module access (App)
  if: inputs.private-modules && steps.app.outputs.token != ''
  run: |
    git config --global url."https://x-access-token:${{ steps.app.outputs.token }}@github.com/ivlholding/".insteadOf "https://github.com/ivlholding/"
    go env -w GOPRIVATE="github.com/ivlholding/*"
    go env -w GOSUMDB=off
```

The existing PAT branch stays as fallback until every repo has migrated.

## Verification

- Trigger scraper-ricardo CI with App configured, PAT secret deleted → passes.
- Check org audit log: should show `integration.token_created` for the App
  on every run.
- Rotate the App private key annually (Settings → the App → roll key).

## Cost

- **Free.** GitHub Apps cost nothing regardless of repo visibility.
- Tokens live 1h by default, auto-refreshed by `create-github-app-token`.

## Migration order

1. User creates App, saves the 2 secrets at org level.
2. Delete `IVL_MODULES_TOKEN` repo secret from scraper-ricardo.
3. Update ivlholding/.github/.github/workflows/go-ci.yml with the App branch.
4. Re-run scraper-ricardo CI to confirm green.
