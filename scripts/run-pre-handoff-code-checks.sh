#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base="${1:?base SHA required}"
pr_json="${2:-}"
head="$(git -C "$repo_root" rev-parse HEAD)"
scratch="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pre-handoff-code-checks.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

git -C "$repo_root" diff --name-only "$base" "$head" -- > "$scratch/changed"
if [[ ! -s "$scratch/changed" ]]; then
  echo "run-pre-handoff-code-checks: no changed files"
  exit 0
fi
cp "$scratch/changed" "$scratch/changed-files"

selector_paths=()
while IFS= read -r path; do
  case "$path" in
    src/lib/*|src/test/*|src/mix.exs|src/mix.lock) selector_paths+=("${path#src/}") ;;
  esac
done < "$scratch/changed"
selector_paths_json="$(python3 - "${selector_paths[@]}" <<'PY'
import json, sys
print(json.dumps(sys.argv[1:]))
PY
)"
selector_paths_b64="$(printf '%s' "$selector_paths_json" | base64 | tr -d '\n')"
(export AIUR_CI_CHANGED_PATHS_B64="$selector_paths_b64"; \
  cd "$repo_root/src" && mise exec -- mix aiur.affected_tests "$base") > "$scratch/selection"
cat "$scratch/selection"
tests_file="$scratch/tests"
: > "$tests_file"
full_ci_ran=false

while IFS= read -r line; do
  case "$line" in
    "cd src && mise exec -- mix test --max-cases 4 "*)
      python3 - "${line#cd src && mise exec -- }" >> "$tests_file" <<'PY'
import shlex, sys
command = shlex.split(sys.argv[1])
if command[:3] != ["mix", "test", "--max-cases"] or command[3] != "4":
    raise SystemExit("unexpected affected-test command")
print("\n".join(command[4:]))
PY
      ;;
    "cd src && mise exec -- make ci"*)
      echo "run-pre-handoff-code-checks: selection requires the full CI suite"
      full_ci_ran=true
      (cd "$repo_root/src" && mise exec -- make ci)
      ;;
  esac
done < "$scratch/selection"

while IFS= read -r path; do
  if [[ "$path" == src/lib/* ]]; then
    if [[ "$path" =~ ^src/lib/aiur/([^/]+)/ ]]; then
      subsystem="aiur/${BASH_REMATCH[1]}"
    elif [[ "$path" =~ ^src/lib/([^/]+)/ ]]; then
      subsystem="${BASH_REMATCH[1]}"
    elif [[ "$path" == src/lib/aiur/* ]]; then
      subsystem=aiur
    else
      subsystem=""
    fi
    if [[ -n "$subsystem" ]]; then
      if [[ -d "$repo_root/src/test/$subsystem" ]]; then
        find "$repo_root/src/test/$subsystem" -type f -name '*_test.exs' -printf "test/$subsystem/%P\n" >> "$tests_file"
      fi
    fi
  fi
done < "$scratch/changed"

run_order_tests=false
if grep -Fxq 'src/lib/aiur/application/children.ex' "$scratch/changed"; then
  run_order_tests=true
elif git -C "$repo_root" diff --unified=8 "$base" "$head" -- src/lib | grep -i 'children' >/dev/null; then
  run_order_tests=true
fi

if [[ "$run_order_tests" == true ]]; then
  printf '%s\n' \
    test/aiur/build_order/component_test.exs \
    test/aiur/voice_quota_test.exs \
    test/aiur/application_child_order_test.exs >> "$tests_file"
fi

if [[ -s "$tests_file" ]]; then
  sort -u "$tests_file" -o "$tests_file"
  mapfile -t tests < "$tests_file"
  echo "run-pre-handoff-code-checks: running selected tests (${#tests[@]} files)"
  (cd "$repo_root/src" && mise exec -- mix test --max-cases 4 "${tests[@]}")
else
  echo "run-pre-handoff-code-checks: no affected tests selected"
fi

if grep -q '^src/lib/' "$scratch/changed" && [[ "$full_ci_ran" != true ]]; then
  echo "run-pre-handoff-code-checks: running dialyzer for src/lib changes"
  (cd "$repo_root/src" && mise exec -- mix dialyzer)
fi

if [[ -n "$pr_json" ]]; then
  PRE_HANDOFF_FULL_CI_RAN="$full_ci_ran" python3 - "$repo_root" "$pr_json" "$head" "$base" "$tests_file" <<'PY'
import json, os, sys, tempfile, subprocess

repo_root, path, checked_out_head, base, tests_path = sys.argv[1:]
changed_path = os.path.join(os.path.dirname(tests_path), "changed-files")
with open(path, encoding="utf-8") as source:
    pr = json.load(source)
head = pr.get("head", {}).get("sha", checked_out_head)
body = pr.get("body") or ""
base_ref = os.environ.get("AIUR_BASE_BRANCH", "main")
base_sha = subprocess.check_output(["git", "-C", repo_root, "rev-parse", base], text=True).strip()
tests = [line for line in open(tests_path, encoding="utf-8").read().splitlines() if line]
full_ci_ran = os.environ.get("PRE_HANDOFF_FULL_CI_RAN") == "true"
selection = "affected-test selector plus changed src/lib subsystem tests and pinned child-order tests"
evidence = [
    "Policy: partial",
    f"Tested head: {head}",
    f"Base: {base_ref} @ {base_sha}",
    f"Selection: {selection}",
]
if full_ci_ran:
    evidence.append("- `mise exec -- make ci` -> passed")
elif tests:
    evidence.append("- `mix test --max-cases 4 " + " ".join(tests) + "` -> passed")
else:
    evidence.append("- `mix test` -> no affected tests selected")
if any(line.startswith("src/lib/") for line in open(changed_path, encoding="utf-8")) and not full_ci_ran:
    evidence.append("- `mix dialyzer` -> passed")
else:
    evidence.append("- `mix dialyzer` -> not required (no src/lib changes)")
section = "## Local tests"
if section in body:
    before, rest = body.split(section, 1)
    next_heading = rest.find("\n## ")
    tail = rest[next_heading:] if next_heading >= 0 else ""
    body = before.rstrip() + "\n\n" + section + "\n" + "\n".join(evidence) + tail
else:
    body = body.rstrip() + "\n\n" + section + "\n" + "\n".join(evidence) + "\n"
pr["body"] = body
fd, temp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".pre-handoff-pr-")
with os.fdopen(fd, "w", encoding="utf-8") as output:
    json.dump(pr, output)
os.replace(temp, path)
PY
  body_file="$scratch/pr-body.md"
  checked_head="$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("head", {}).get("sha", sys.argv[2]))' "$pr_json" "$head")"
  python3 - "$pr_json" "$body_file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    body = json.load(source).get("body") or ""
with open(sys.argv[2], "w", encoding="utf-8") as output:
    output.write(body)
PY
  (cd "$repo_root/src" && mise exec -- mix pr_body.check --file "$body_file" --head "$checked_head")
fi
