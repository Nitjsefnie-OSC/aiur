#!/usr/bin/env bash
# Event selects fast/full CI; operator policy can force full CI on a PR.
set -euo pipefail
if [[ "$EVENT_NAME" != pull_request ]]; then
  printf 'full_ci=true\ndocs_only=false\n' >> "$GITHUB_OUTPUT"
  echo "event $EVENT_NAME: full CI" >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi
PR_JSON="$(gh api "repos/$REPO/pulls/$PR_NUMBER")"
FILES_JSON="$(gh api --paginate --slurp "repos/$REPO/pulls/$PR_NUMBER/files" | jq 'add')"
export PR_JSON FILES_JSON
# Read policy from the base: a PR cannot weaken its own full-CI requirement.
policy="$(mktemp)"
trap 'rm -f "$policy"' EXIT
base="$(jq -er '.base.sha' <<< "$PR_JSON")"
git -C "${GITHUB_WORKSPACE:-.}" show "$base:.aiur/config" > "$policy"
ruby scripts/ci-policy.rb "$policy" | tee -a "$GITHUB_OUTPUT" >> "$GITHUB_STEP_SUMMARY"
