#!/usr/bin/env bash
# Apply the canonical branch-protection ruleset to every ivlholding/* repo.
# Idempotent: updates in-place when the name matches, creates otherwise.
#
# Usage: ./scripts/apply-rulesets.sh [--dry-run]
#
# Requires: gh CLI authenticated with admin:repo_hook scope on the org.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

RULESET_FILE="$(dirname "$0")/../rulesets/branch-protection.json"
RULESET_NAME=$(jq -r .name "$RULESET_FILE")

REPOS=(
  scraper-core
  scraper-gateway
  scraper-ricardo
  proxy-hub
  scraper-apis
  scraper-infra
  .github
)

for repo in "${REPOS[@]}"; do
  echo "=== ivlholding/$repo ==="

  # Look for an existing ruleset with this name.
  EXISTING_ID=$(gh api "repos/ivlholding/$repo/rulesets" 2>/dev/null \
    | jq -r ".[] | select(.name==\"$RULESET_NAME\") | .id" || true)

  if [ "$DRY_RUN" = "1" ]; then
    [ -n "$EXISTING_ID" ] && echo "  would UPDATE ruleset $EXISTING_ID" || echo "  would CREATE ruleset"
    continue
  fi

  if [ -n "$EXISTING_ID" ]; then
    gh api -X PUT "repos/ivlholding/$repo/rulesets/$EXISTING_ID" \
      --input "$RULESET_FILE" >/dev/null
    echo "  updated ruleset $EXISTING_ID"
  else
    gh api -X POST "repos/ivlholding/$repo/rulesets" \
      --input "$RULESET_FILE" >/dev/null
    echo "  created ruleset"
  fi
done
