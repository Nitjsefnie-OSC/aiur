#!/usr/bin/env bash
# Merge groups always run full CI; PRs opt in with a full-CI label.
set -euo pipefail
if [[ "$EVENT_NAME" != pull_request ]]; then
  if [[ "$EVENT_NAME" == merge_group || "$EVENT_NAME" == workflow_dispatch || "${GITHUB_REF:-}" == refs/heads/v2 ]]; then
    printf 'full_ci=true\ndocs_only=false\n' >> "$GITHUB_OUTPUT"
    echo "event $EVENT_NAME: full CI" >> "$GITHUB_STEP_SUMMARY"
  else
    printf 'full_ci=false\ndocs_only=false\n' >> "$GITHUB_OUTPUT"
    echo "event $EVENT_NAME: quarantine only" >> "$GITHUB_STEP_SUMMARY"
  fi
  printf 'affected_paths_b64=\n' >> "$GITHUB_OUTPUT"
  exit 0
fi
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
gh api "repos/$REPO/pulls/$PR_NUMBER" > "$scratch/pr.json"
gh api --paginate --slurp "repos/$REPO/pulls/$PR_NUMBER/files" \
  | jq 'add | map({filename, previous_filename})' > "$scratch/files.json"
# Read opt-in labels from the base: a PR cannot alter its own selection policy.
base="$(jq -er '.base.sha' "$scratch/pr.json")"
git -C "${GITHUB_WORKSPACE:-.}" show "$base:.aiur/config" > "$scratch/policy"
ruby scripts/ci-policy.rb "$scratch/policy" "$scratch/pr.json" "$scratch/files.json" > "$scratch/classification"
if [[ "${EVENT_NAME}" == pull_request ]] && grep -qx 'full_ci=false' "$scratch/classification" && ! grep -qx 'docs_only=true' "$scratch/classification"; then
  jq -r '.[] | .filename, (.previous_filename // empty)' "$scratch/files.json" > "$scratch/paths"
  selection="$(elixir -r src/lib/aiur/affected_tests.ex scripts/ci-test-selection.exs "$scratch/paths")"
  case "$selection" in
    full|scoped:*) ;;
    *) echo "unsupported affected selection: $selection" >&2; exit 1 ;;
  esac
fi
if grep -qx 'full_ci=false' "$scratch/classification"; then
  paths_b64="$(jq -cj '[.[] | .filename, (.previous_filename | select(. != null))] | unique' "$scratch/files.json" | base64 -w0)"
  echo "affected_paths_b64=$paths_b64" >> "$GITHUB_OUTPUT"
else
  echo 'affected_paths_b64=' >> "$GITHUB_OUTPUT"
fi
cat "$scratch/classification" | tee -a "$GITHUB_OUTPUT" >> "$GITHUB_STEP_SUMMARY"
