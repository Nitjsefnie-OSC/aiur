defmodule Aiur.AgentScratchTest do
  use Aiur.TestSupport

  alias Aiur.AgentEnvironment
  alias Aiur.Config.CodexSandboxPolicy

  test "agent temp files stay in the workspace and Codex denies direct /tmp writes" do
    workspace = Aiur.TestSupport.tmp_root!("agent-scratch-command")
    File.mkdir_p!(workspace)
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(workspace) end)

    assert CodexSandboxPolicy.default_policy(workspace)["excludeSlashTmp"]

    env =
      AgentEnvironment.workspace_env(workspace)
      |> Enum.filter(fn {name, _} -> name in [~c"TMPDIR", ~c"TMP", ~c"TEMP"] end)
      |> Enum.map(fn {name, value} -> {to_string(name), to_string(value)} end)

    {path, 0} =
      System.cmd(
        "python3",
        [
          "-c",
          "import tempfile; f = tempfile.NamedTemporaryFile(delete=False); print(f.name); f.close()"
        ], env: env)

    path = String.trim(path)
    assert Path.dirname(path) == Path.join(workspace, ".aiur-runtime/tmp")
    assert File.regular?(path)
    Aiur.TestCleanup.rm_rf!(path)
  end
end
