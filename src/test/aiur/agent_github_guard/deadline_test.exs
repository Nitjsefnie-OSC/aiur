defmodule Aiur.AgentGitHubGuard.DeadlineTest do
  use Aiur.AgentGitHubGuardCase, async: true

  test "a broker that never answers is terminated with the governed call", context do
    broker = Path.join(context.workspace, "never-answers.py")
    pid_file = Path.join(context.workspace, "broker.pid")
    child_pid_file = Path.join(context.workspace, "broker-child.pid")

    File.write!(broker, """
    import os, subprocess, time
    child = subprocess.Popen(["/bin/sh", "-c", "trap '' TERM; exec sleep 5"])
    with open(os.environ["AIUR_GH_NEVER_ANSWERS_CHILD_PID_FILE"], "w", encoding="utf-8") as pid_file:
        pid_file.write(str(child.pid))
    with open(os.environ["AIUR_GH_NEVER_ANSWERS_PID_FILE"], "w", encoding="utf-8") as pid_file:
        pid_file.write(str(os.getpid()))
    time.sleep(5)
    """)

    File.chmod!(broker, 0o700)

    started_at = System.monotonic_time(:millisecond)

    assert {output, 124} =
             run_guard(context, ["api", "rate_limit"],
               AIUR_GH_CALL_TIMEOUT_SECONDS: "1",
               AIUR_GITHUB_BUDGET_ROOT: Path.join(context.state_path, "budget"),
               AIUR_GITHUB_BUDGET_KEY: String.duplicate("a", 64),
               AIUR_GITHUB_BUDGET_BROKER: broker,
               AIUR_GH_NEVER_ANSWERS_CHILD_PID_FILE: child_pid_file,
               AIUR_GH_NEVER_ANSWERS_PID_FILE: pid_file
             )

    assert output =~ "governed gh call exceeded 1s deadline; terminated process group"
    assert System.monotonic_time(:millisecond) - started_at < 4_000

    broker_pid = pid_file |> File.read!() |> String.to_integer()
    assert process_gone?(broker_pid)
    child_pid = child_pid_file |> File.read!() |> String.to_integer()
    assert process_gone?(child_pid)
  end

  defp process_gone?(pid) do
    case File.read("/proc/#{pid}/stat") do
      {:ok, stat} ->
        stat |> String.split() |> Enum.at(2) == "Z"

      {:error, :enoent} ->
        true
    end
  end
end
