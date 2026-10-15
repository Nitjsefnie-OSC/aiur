#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-$repo_root/.aiur-runtime/tmp}/pre-handoff-test.XXXXXX")"
fixture=""
cleanup() {
  [[ -z "$fixture" ]] || rm -f "$fixture"
  rm -rf "$tmp"
}
trap cleanup EXIT

base="$(git -C "$repo_root" rev-parse HEAD)"
head="$base"
cat > "$tmp/pr.json" <<JSON
{"created_at":"1970-01-01T00:00:00Z","body":"","head":{"sha":"$head"}}
JSON

cd "$repo_root"
scripts/pre-handoff-guards "$tmp/pr.json" "$base" > "$tmp/clean.log"
scripts/pre-handoff-guards --skip-pr-body "$base" > "$tmp/non-pr.log"

mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
cat "$PR_METADATA"
GH
chmod +x "$tmp/bin/gh"
for event in pull_request merge_group push workflow_dispatch schedule; do
  env GITHUB_EVENT_NAME="$event" GITHUB_REPOSITORY=example/repo AIUR_PR_NUMBER=1 \
    AIUR_PR_BASE_SHA="$base" AIUR_MERGE_BASE_SHA="$base" AIUR_PUSH_BEFORE="$base" \
    RUNNER_TEMP="$tmp" PR_METADATA="$tmp/pr.json" PATH="$tmp/bin:$PATH" \
    scripts/run-pre-handoff-guards.sh > "$tmp/$event.log"
done
grep -F 'scripts/check-pr-body.py' "$tmp/pull_request.log" >/dev/null
for event in merge_group push workflow_dispatch schedule; do
  ! grep -F 'scripts/check-pr-body.py' "$tmp/$event.log" >/dev/null
done
for event in pull_request merge_group push workflow_dispatch schedule; do
  for guard in check-on-exit-rm-rf.py check-bare-assert-receive.py check-hot-list-format.py check-file-size.py; do
    grep -F "scripts/$guard" "$tmp/$event.log" >/dev/null
  done
done

fixture="$(mktemp "$repo_root/src/test/aiur/pre_handoff_guard_fixture.XXXXXX.exs")"
cat > "$fixture" <<'ELIXIR'
on_exit(fn -> File.rm_rf!("/tmp/pre-handoff-guard-fixture") end)
ELIXIR

if scripts/pre-handoff-guards "$tmp/pr.json" "$base" > "$tmp/bare-rm-rf.log" 2>&1; then
  echo "test-pre-handoff-guards: expected bare File.rm_rf! fixture to fail" >&2
  exit 1
fi
grep -F 'check-on-exit-rm-rf: bare File.rm_rf in on_exit; use Aiur.TestCleanup.rm_rf!/1:' "$tmp/bare-rm-rf.log" >/dev/null
grep -F "${fixture#"$repo_root/"}:1:" "$tmp/bare-rm-rf.log" >/dev/null

echo "test-pre-handoff-guards: clean PR and non-PR paths pass; bare cleanup fails with CI diagnostic"
