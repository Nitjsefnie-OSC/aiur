#!/usr/bin/env bash
set -euo pipefail

case "${GITHUB_EVENT_NAME:?}" in
  pull_request)
    gh api "repos/$GITHUB_REPOSITORY/pulls/${AIUR_PR_NUMBER:?}" > "$RUNNER_TEMP/pr-evidence.json"
    ;;
  merge_group)
    code_base="${AIUR_MERGE_BASE_SHA:?}"
    ;;
  push)
    code_base="${AIUR_PUSH_BEFORE:?}"
    if [[ "$code_base" =~ ^0+$ ]]; then code_base="$(git rev-parse HEAD^1)"; fi
    ;;
  workflow_dispatch)
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo origin/main)"
    code_base="$(git merge-base HEAD "$upstream")"
    ;;
  schedule)
    code_base="$(git merge-base HEAD origin/main)"
    ;;
  *) echo "Unsupported pre-handoff guard event: $GITHUB_EVENT_NAME" >&2; exit 1 ;;
esac

if [[ "$GITHUB_EVENT_NAME" == pull_request ]]; then
  scripts/run-pre-handoff-code-checks.sh "$AIUR_PR_BASE_SHA" "$RUNNER_TEMP/pr-evidence.json"
  head_repo="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("head", {}).get("repo", {}).get("full_name", ""))' "$RUNNER_TEMP/pr-evidence.json")"
  if [[ "$head_repo" == "$GITHUB_REPOSITORY" ]]; then
    gh api --method PATCH "repos/$GITHUB_REPOSITORY/pulls/$AIUR_PR_NUMBER" \
      -F "body=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["body"])' "$RUNNER_TEMP/pr-evidence.json")" >/dev/null
    gh api "repos/$GITHUB_REPOSITORY/pulls/$AIUR_PR_NUMBER" > "$RUNNER_TEMP/pr-evidence-verified.json"
    python3 - "$RUNNER_TEMP/pr-evidence.json" "$RUNNER_TEMP/pr-evidence-verified.json" <<'PY'
import json, sys
expected = json.load(open(sys.argv[1], encoding="utf-8"))["body"]
actual = json.load(open(sys.argv[2], encoding="utf-8"))["body"]
if actual != expected:
    raise SystemExit("run-pre-handoff-guards: PR Local tests evidence did not persist exactly")
PY
  else
    echo "run-pre-handoff-guards: PR body evidence update skipped for fork PR (token is read-only)"
  fi
  if [[ -f "$RUNNER_TEMP/pr-evidence-verified.json" ]]; then
    scripts/pre-handoff-guards "$RUNNER_TEMP/pr-evidence-verified.json" "$AIUR_PR_BASE_SHA"
  else
    scripts/pre-handoff-guards "$RUNNER_TEMP/pr-evidence.json" "$AIUR_PR_BASE_SHA"
  fi
else
  scripts/pre-handoff-guards --skip-pr-body "$code_base"
  scripts/run-pre-handoff-code-checks.sh "$code_base"
fi

python3 scripts/check-config-docs.py
node scripts/check-docs-prose.mjs
