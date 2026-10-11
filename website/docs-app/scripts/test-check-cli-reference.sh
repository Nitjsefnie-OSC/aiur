#!/usr/bin/env bash
# Guards the CLI reference checker against missing flags and unscanned modules.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

scaffold() {
  local root="$1"
  mkdir -p "$root/website/docs-app" "$root/packaging/npm/aiur-cli" "$root/src/lib/aiur" "$root/scripts"
  cp -R "$repo_root/website/docs-app/scripts" "$root/website/docs-app/"
  cp -R "$repo_root/website/docs-app/reference" "$root/website/docs-app/"
  cp -R "$repo_root/packaging/npm/aiur-cli/libexec" "$root/packaging/npm/aiur-cli/"
  cp "$repo_root/src/lib/aiur/cli.ex" "$root/src/lib/aiur/"
  cp "$repo_root/src/lib/aiur/experiments_cli.ex" "$repo_root/src/lib/aiur/alerts_cli.ex" "$root/src/lib/aiur/"
  cp "$repo_root/scripts/aiurdev" "$root/scripts/"
}

run_check() {
  (cd "$1" && bash website/docs-app/scripts/check-cli-reference.sh 2>&1)
}

root="$work/missing"
scaffold "$root"
cat >"$root/packaging/npm/aiur-cli/libexec/aiur-new-control.sh" <<'MODULE'
new_control() {
  case "$1" in
    --new-flag) ;;
  esac
}
MODULE
printf '%s\n' 'source "$(dirname "${BASH_SOURCE[0]}")/aiur-new-control.sh"' >>"$root/packaging/npm/aiur-cli/libexec/aiur-engine.sh"
if output="$(run_check "$root")"; then
  fail "an undocumented flag in a new libexec module passed"
fi
grep -q -- '--new-flag' <<<"$output" ||
  fail "the missing-flag failure did not name --new-flag: $output"

root="$work/documented"
scaffold "$root"
cat >"$root/packaging/npm/aiur-cli/libexec/aiur-new-control.sh" <<'MODULE'
new_control() {
  case "$1" in
    --new-flag) ;;
  esac
}
MODULE
printf '%s\n' 'source "$(dirname "${BASH_SOURCE[0]}")/aiur-new-control.sh"' >>"$root/packaging/npm/aiur-cli/libexec/aiur-engine.sh"
cat >>"$root/website/docs-app/reference/cli.md" <<'DOC'
| `--new-flag` | Select the new mode. | `aiur status --new-flag` |
DOC
if output="$(run_check "$root")"; then
  :
else
  fail "a documented flag in a new libexec module failed: $output"
fi

echo "check-cli-reference guard: all cases passed"
