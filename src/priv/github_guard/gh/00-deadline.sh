# Fragment of the assembled `gh` guard (Aiur.AgentGitHubGuard.Script); not a standalone script.
#!/bin/sh
# Keep the complete governed call, including broker and real-gh descendants,
# inside one process group so a deadline can terminate every child.
if command -v python3 >/dev/null 2>&1; then
  exec python3 -c '
import os, signal, subprocess, sys, tempfile

script = sys.argv[1]
args = sys.argv[2:]
with open(script, encoding="utf-8") as source:
    assembled = source.read()
marker = "# @aiur-deadline-body@\n"
if marker not in assembled:
    print("aiur: governed gh guard has no deadline body", file=sys.stderr)
    raise SystemExit(127)
body = assembled.split(marker, 1)[1]
try:
    seconds = int(os.environ.get("AIUR_GH_CALL_TIMEOUT_SECONDS", "120"))
except ValueError:
    seconds = 120
seconds = max(1, min(seconds, 120))
fd, body_path = tempfile.mkstemp(prefix="aiur-gh-guard.", suffix=".sh")
with os.fdopen(fd, "w", encoding="utf-8") as body_file:
    body_file.write(body)
child = subprocess.Popen(
    ["/bin/sh", "-c", "script=$1; shift; . \"$script\"", script, body_path, *args],
    stdin=None,
    start_new_session=True,
)

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
    child.wait(timeout=seconds)
except subprocess.TimeoutExpired:
    terminate_process_group()
    print(f"aiur: governed gh call exceeded {seconds}s deadline; terminated process group", file=sys.stderr)
    raise SystemExit(124)
finally:
    os.unlink(body_path)
status = child.returncode
raise SystemExit(status if status >= 0 else 128 - status)
' "$0" "$@"
elif [ "${1:-}" != --validate-issue-command ]; then
  printf '%s\n' 'aiur: python3 is required to enforce the governed gh call deadline' >&2
  exit 127
fi
# The supervised child starts here, after the launcher, so no inherited
# environment marker can bypass the deadline by skipping the launcher.
# @aiur-deadline-body@
