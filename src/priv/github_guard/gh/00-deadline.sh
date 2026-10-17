# Fragment of the assembled `gh` guard (Aiur.AgentGitHubGuard.Script); not a standalone script.
#!/bin/sh
# Keep the complete governed call, including broker and real-gh descendants,
# inside one process group so a deadline can terminate every child.
if [ "${AIUR_GH_GUARD_SUPERVISED:-0}" != 1 ]; then
  if command -v python3 >/dev/null 2>&1; then
    exec python3 -c '
import os, signal, subprocess, sys

script, *args = sys.argv[1:]
try:
    seconds = int(os.environ.get("AIUR_GH_CALL_TIMEOUT_SECONDS", "120"))
except ValueError:
    seconds = 120
seconds = max(1, min(seconds, 120))
env = os.environ.copy()
env["AIUR_GH_GUARD_SUPERVISED"] = "1"
env.pop("AIUR_GH_GUARD_DEPTH", None)
env.pop("AIUR_GH_GUARD_CALL", None)
child = subprocess.Popen(["/bin/sh", script, *args], env=env, start_new_session=True)

def terminate_process_group():
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait()

def stop_child(signum, _frame):
    terminate_process_group()
    raise SystemExit(128 + signum)

signal.signal(signal.SIGTERM, stop_child)
signal.signal(signal.SIGINT, stop_child)
signal.signal(signal.SIGHUP, stop_child)
try:
    status = child.wait(timeout=seconds)
except subprocess.TimeoutExpired:
    terminate_process_group()
    print(f"aiur: governed gh call exceeded {seconds}s deadline; terminated process group", file=sys.stderr)
    raise SystemExit(124)
raise SystemExit(status if status >= 0 else 128 - status)
' "$0" "$@"
  elif [ "${1:-}" != --validate-issue-command ]; then
    printf '%s\n' 'aiur: python3 is required to enforce the governed gh call deadline' >&2
    exit 127
  fi
fi
