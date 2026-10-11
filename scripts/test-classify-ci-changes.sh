#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/aiur-classify-ci.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
mkdir "$test_dir/bin"
cat > "$test_dir/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *'/files'*) printf '[%s]\n' "$TEST_FILES" ;;
  *) printf '{"base":{"sha":"base-sha"},"labels":%s,"draft":%s}\n' "$TEST_LABELS" "$TEST_DRAFT" ;;
esac
STUB
cat > "$test_dir/bin/git" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == *'base-sha:.aiur/config' ]] || exit 2
cat <<'YAML'
merge_policy:
  full_ci_labels: [main-fix, urgent]
  full_ci_paths: [".github/workflows/**", "src/mix.exs", "**/mix.lock"]
YAML
STUB
chmod +x "$test_dir/bin/gh" "$test_dir/bin/git"
classify() {
  : > "$test_dir/out"
  EVENT_NAME="$1" TEST_DRAFT="$2" TEST_FILES="$3" TEST_LABELS="${4:-[]}" REPO=o/r PR_NUMBER=7 \
    GITHUB_OUTPUT="$test_dir/out" GITHUB_STEP_SUMMARY="$test_dir/summary" \
    PATH="$test_dir/bin:$PATH" bash "$root/scripts/classify-ci-changes.sh"
  sort "$test_dir/out" | paste -sd' ' -
}
expect() {
  local want="$1" got; shift
  got="$(classify "$@")"
  [[ "$got" == "$want" ]] || { echo "expected '$want', got '$got'" >&2; exit 1; }
}
for draft in true false; do
  expect 'docs_only=false full_ci=false' pull_request "$draft" '[{"filename":"src/lib/aiur/config.ex"}]'
  expect 'docs_only=true full_ci=false' pull_request "$draft" '[{"filename":"website/docs-app/guide/a.md"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":".github/workflows/ci.yml"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":"src/mix.lock"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":"mix.lock"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":"website/new.md","previous_filename":"src/mix.exs"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":"website/new.md"}]' '[{"name":"MAIN-FIX"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[{"filename":"website/new.md"}]' '[{"name":"urgent"}]'
  expect 'docs_only=false full_ci=true' pull_request "$draft" '[]'
done
for event in merge_group workflow_dispatch; do
  expect 'docs_only=false full_ci=true' "$event" true '[]'
done
workflow="$root/.github/workflows/ci.yml"
! grep -q 'outputs.draft\|pull_request.draft' "$workflow"
grep -Fq 'full_ci: ${{ steps.classify.outputs.full_ci }}' "$workflow"
grep -Fq 'run: bash scripts/classify-ci-changes.sh' "$workflow"
grep -Fq 'run: bash scripts/test-classify-ci-changes.sh' "$workflow"
echo 'CI classifier event, policy, rename and draft tests passed'
