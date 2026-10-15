defmodule Aiur.AgentGitHubGuard.TimedCommandCleanupTest do
  use Aiur.AgentGitHubGuardCase, async: true

  test "a timed-out command cannot leave descendants holding its output pipes", context do
    timeout = System.find_executable("timeout") || flunk("timeout executable is required for this Linux-only guard test")
    child = Path.join(context.state_path, "pipe-holder.sh")
    child_pid = Path.join(context.state_path, "pipe-holder.pid")

    File.mkdir_p!(context.state_path)
    File.write!(child, "#!/bin/sh\nsleep 60 &\necho $! > \"$TIMEOUT_CHILD_PID_FILE\"\nwait\n")
    File.chmod!(child, 0o755)

    started_at = System.monotonic_time(:millisecond)
    assert {_output, 124} = run_timed_command(timeout, "0.2", child, [], env: [{"TIMEOUT_CHILD_PID_FILE", child_pid}])
    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    assert elapsed_ms < 5_000
    assert {pid, ""} = Integer.parse(String.trim(File.read!(child_pid)))

    case System.cmd("ps", ["-o", "stat=", "-p", Integer.to_string(pid)], stderr_to_stdout: true) do
      {"", 1} -> :ok
      {state, 0} -> assert String.starts_with?(String.trim(state), "Z")
      {output, status} -> flunk("could not inspect timed child: exit #{status}, #{inspect(output)}")
    end
  end
end
