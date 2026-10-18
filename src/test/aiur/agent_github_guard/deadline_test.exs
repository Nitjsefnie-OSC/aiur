defmodule Aiur.AgentGitHubGuard.DeadlineTest do
  use Aiur.AgentGitHubGuardCase, async: true

  test "a broker that never answers is terminated with the governed call", context do
    slow_gh = Path.join(context.workspace, "slow-gh")
    File.write!(slow_gh, "#!/bin/sh\nprintf 'started' > \"$START_FILE\"\nsleep 5\n")
    File.chmod!(slow_gh, 0o700)
    started = Path.join(context.workspace, "started")

    assert {output, 124} =
             run_guard(context, ["auth", "status"],
               AIUR_GH_CALL_TIMEOUT_SECONDS: "1",
               AIUR_REAL_GH: slow_gh,
               START_FILE: started,
               AIUR_GITHUB_BUDGET_ENABLED: "0"
             )

    assert output =~ "governed gh call exceeded 1s deadline"
    assert File.read!(started) == "started"
  end

  test "the supervisor preserves wrapper argv0 and caller stdin", context do
    stdin_file = Path.join(context.workspace, "stdin")
    File.write!(stdin_file, "")
    fake_gh = Path.join(context.workspace, "fake-gh")
    File.write!(fake_gh, "#!/bin/sh\ncat > \"$GH_STDIN_FILE\"\nprintf 'ok\\n'\n")
    File.chmod!(fake_gh, 0o700)

    env = guard_env(context) ++ [{"AIUR_REAL_GH", fake_gh}, {"GH_STDIN_FILE", stdin_file}, {"AIUR_GITHUB_BUDGET_ENABLED", "0"}]

    assert {"ok\n", 0} =
             System.cmd("sh", ["-c", "printf '%s' \"$2\" | \"$1\" auth status", "sh", context.wrapper, "caller graphql body"],
               env: env,
               stderr_to_stdout: true
             )

    assert File.read!(stdin_file) == "caller graphql body"
  end

  test "the guard body cannot be swapped through the caller TMPDIR", context do
    tmpdir = Path.join(context.workspace, "tmp")
    File.mkdir_p!(tmpdir)
    marker = Path.join(context.workspace, "swapped-code-ran")
    fake_gh = Path.join(context.workspace, "fake-gh")

    File.write!(fake_gh, "#!/bin/sh\nprintf 'ok\\n'\n")
    File.chmod!(fake_gh, 0o700)

    assert {"ok\n", 0} =
             run_guard(context, ["auth", "status"],
               TMPDIR: tmpdir,
               AIUR_REAL_GH: fake_gh,
               AIUR_GITHUB_BUDGET_ENABLED: "0",
               AIUR_GH_CALL_TIMEOUT_SECONDS: "2"
             )

    refute File.exists?(marker)
    assert Path.wildcard(Path.join(tmpdir, "aiur-gh-guard.*")) == []
  end
end
