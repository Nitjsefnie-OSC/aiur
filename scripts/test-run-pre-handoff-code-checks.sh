#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pre-handoff-code-checks-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fixture="$tmp/repo"
mkdir -p "$fixture/scripts" "$fixture/src/test/aiur/github" "$tmp/bin"
cp "$repo_root/scripts/run-pre-handoff-code-checks.sh" "$fixture/scripts/"
touch "$fixture/src/test/aiur/foo_test.exs" "$fixture/src/test/aiur/github/subsystem_test.exs"

cat > "$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
case "$*" in
  *"diff --name-only"*) printf '%s\n' "$CHANGED_PATHS" ;;
  *"diff --unified=8"*) [[ "$CHANGED_PATHS" == *application/children.ex* ]] && printf '%s\n' '+children: [Aiur.Supervisor]' ;;
  *"rev-parse HEAD"*) printf '%s\n' "$HEAD_SHA" ;;
  *"rev-parse $BASE_SHA"*) printf '%s\n' "$BASE_SHA" ;;
  *) echo "unexpected git args: $*" >&2; exit 90 ;;
esac
GIT

cat > "$tmp/bin/mix" <<'MIX'
#!/usr/bin/env bash
case "$*" in
  "aiur.affected_tests "*)
    printf 'selector:%s\n' "${AIUR_CI_CHANGED_PATHS_B64:-}" >> "$COMMAND_LOG"
    if [[ "$CHANGED_PATHS" == *src/test/support/* || "$CHANGED_PATHS" == *src/mix.exs || "$CHANGED_PATHS" == *src/mix.lock || "$CHANGED_PATHS" == *src/config/* ]]; then
      printf '%s\n' 'cd src && mise exec -- make ci'
      exit 0
    fi
    if [[ "$(printf '%s' "${AIUR_CI_CHANGED_PATHS_B64:-}" | base64 --decode)" == '[]' ]]; then
      printf '%s\n' 'cd src && mise exec -- mix test --max-cases 4'
      exit 0
    fi
    printf '%s\n' "cd src && mise exec -- mix test --max-cases 4 'test/aiur/foo test.exs'"
    ;;
  pr_body.check*) printf 'body-check\n' >> "$COMMAND_LOG" ;;
  "test --max-cases 4 "*)
    printf 'test:%s\n' "$*" >> "$COMMAND_LOG"
    [[ "${FAIL_TEST:-}" != true ]]
    ;;
  dialyzer)
    printf 'dialyzer\n' >> "$COMMAND_LOG"
    [[ "${FAIL_DIALYZER:-}" != true ]]
    ;;
  "make ci")
    printf 'make-ci\n' >> "$COMMAND_LOG"
    [[ "${FAIL_FULL_CI:-}" != true ]]
    ;;
  *) echo "unexpected mix args: $*" >&2; exit 91 ;;
esac
MIX

cat > "$tmp/bin/mise" <<'MISE'
#!/usr/bin/env bash
[[ "$1 $2" == "exec --" ]] || exit 92
shift 2
exec "$@"
MISE
cat > "$tmp/bin/make" <<'MAKE'
#!/usr/bin/env bash
[[ "$*" == "ci" ]] || exit 93
printf 'make-ci\n' >> "$COMMAND_LOG"
[[ "${FAIL_FULL_CI:-}" != true ]]
MAKE
chmod +x "$tmp/bin/git" "$tmp/bin/mix" "$tmp/bin/mise" "$tmp/bin/make" "$fixture/scripts/run-pre-handoff-code-checks.sh"

base="$(printf 'a%.0s' {1..40})"
head="$(printf 'b%.0s' {1..40})"
run_check() {
  local name="$1" changed="$2" fail_test="$3" fail_dialyzer="$4" pr_json="${5:-}" fail_full_ci="${6:-false}"
  : > "$tmp/$name.commands"
  if env BASH_ENV=/dev/null PATH="$tmp/bin:$PATH" TMPDIR="$tmp" COMMAND_LOG="$tmp/$name.commands" \
      CHANGED_PATHS="$changed" HEAD_SHA="$head" BASE_SHA="$base" \
      FAIL_TEST="$fail_test" FAIL_DIALYZER="$fail_dialyzer" FAIL_FULL_CI="$fail_full_ci" \
      bash "$fixture/scripts/run-pre-handoff-code-checks.sh" "$base" ${pr_json:+"$pr_json"} > "$tmp/$name.log" 2>&1; then
    return 0
  else
    return 1
  fi
}

if run_check failing_test src/lib/aiur/github/foo.ex true false; then
  echo 'test-run-pre-handoff-code-checks: expected failing selected test to refuse handoff' >&2
  exit 1
fi
grep -F 'test:' "$tmp/failing_test.commands" >/dev/null
grep -F 'foo test.exs' "$tmp/failing_test.commands" >/dev/null
grep -F 'subsystem_test.exs' "$tmp/failing_test.commands" >/dev/null
encoded_paths="$(grep '^selector:' "$tmp/failing_test.commands" | cut -d: -f2-)"
decoded_paths="$(printf '%s' "$encoded_paths" | base64 --decode)"
[[ "$decoded_paths" == '["src/lib/aiur/github/foo.ex"]' ]]
if grep -F 'dialyzer' "$tmp/failing_test.commands" >/dev/null; then
  echo 'test-run-pre-handoff-code-checks: Dialyzer ran after selected tests failed' >&2
  exit 1
fi

if run_check failing_dialyzer src/lib/aiur/foo.ex false true; then
  echo 'test-run-pre-handoff-code-checks: expected Dialyzer failure to refuse handoff' >&2
  exit 1
fi
grep -F 'dialyzer' "$tmp/failing_dialyzer.commands" >/dev/null

if ! run_check passing src/lib/aiur/github/foo.ex false false; then
  cat "$tmp/passing.log" >&2
  echo 'test-run-pre-handoff-code-checks: passing checks were rejected' >&2
  exit 1
fi

if run_check failing_full_ci src/test/support/foo.ex false false "" true; then
  echo 'test-run-pre-handoff-code-checks: expected full-suite failure to refuse handoff' >&2
  exit 1
fi
grep -F 'make-ci' "$tmp/failing_full_ci.commands" >/dev/null

if ! run_check runtime_config src/config/runtime.exs false false; then
  cat "$tmp/runtime_config.log" >&2
  echo 'test-run-pre-handoff-code-checks: runtime config did not trigger full CI' >&2
  exit 1
fi
grep -F 'make-ci' "$tmp/runtime_config.commands" >/dev/null

if ! run_check script_only scripts/run-pre-handoff-code-checks.sh false false; then
  cat "$tmp/script_only.log" >&2
  echo 'test-run-pre-handoff-code-checks: script-only changes were rejected' >&2
  exit 1
fi
grep -F 'selector:W10=' "$tmp/script_only.commands" >/dev/null
grep -F 'no affected tests selected' "$tmp/script_only.log" >/dev/null

pr_json="$tmp/pr.json"
python3 - "$pr_json" "$head" <<'PY'
import json, sys
with open(sys.argv[1], "w", encoding="utf-8") as output:
    json.dump({"head": {"sha": sys.argv[2]}, "body": "## Local tests\nPolicy: partial\nTested head: " + "a" * 40 + "\nBase: main @ " + "a" * 40 + "\nSelection: previous\n- `mix test` -> previous\n"}, output)
PY
if ! run_check evidence src/lib/aiur/foo.ex false false "$pr_json"; then
  cat "$tmp/evidence.log" >&2
  echo 'test-run-pre-handoff-code-checks: PR body evidence generation failed' >&2
  exit 1
fi
python3 - "$pr_json" "$head" <<'PY'
import json, sys
body = json.load(open(sys.argv[1], encoding="utf-8"))["body"]
assert f"Tested head: {sys.argv[2]}" in body
assert f"Base: main @ {'a' * 40}" in body
assert "Selection: affected-test selector plus changed src/lib subsystem tests and pinned child-order tests" in body
assert "- `mix test --max-cases 4" in body and "-> passed" in body
assert "- `mix dialyzer` -> passed" in body
PY

echo 'test-run-pre-handoff-code-checks: selected test and Dialyzer failures refuse handoff'
