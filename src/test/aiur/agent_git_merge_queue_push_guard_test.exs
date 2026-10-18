defmodule Aiur.AgentGitMergeQueuePushGuardTest do
  use ExUnit.Case, async: true
  @moduletag :tmp_dir

  alias Aiur.AgentGitHubGuard

  setup %{tmp_dir: root} do
    workspace = Path.join(root, "4200")
    File.mkdir_p!(workspace)
    :ok = AgentGitHubGuard.install(workspace)
    bin = AgentGitHubGuard.bin_dir(workspace)
    # Inside an agent workspace PATH resolves `git` to the guard itself; a fake
    # that execs the guard recurses without end (it took the host down once).
    real_git = System.get_env("AIUR_REAL_GIT") || System.find_executable("git")
    refute real_git =~ ".aiur-runtime/bin", "resolved the agent git guard instead of the real git"

    # Stands in for the governed gh: answers the guard's one GraphQL lookup.
    File.write!(
      Path.join(bin, "gh"),
      "#!/bin/sh\ncase \"$*\" in *graphql*) printf '%s\\n' \"${FAKE_QUEUE_STATE:-false MERGEABLE APPROVED}\" ;; *issues/*join*) printf '%s %s\\n' 'priority:2' \"${FAKE_TICKET_STATE:-agent:in-progress}\" ;; *issues/*) printf '%s\\n%s\\n' 'priority:2' \"${FAKE_TICKET_STATE:-agent:in-progress}\" ;; *) exit 1 ;; esac\n"
    )

    File.chmod!(Path.join(bin, "gh"), 0o755)

    # Real git for everything but the push itself, which must not reach GitHub.
    fake_git = Path.join(root, "git")

    File.write!(
      fake_git,
      "#!/bin/sh\n[ -z \"${FAKE_GIT_ENTERED:-}\" ] || { echo 'fake git re-entered' >&2; exit 97; }\nexport FAKE_GIT_ENTERED=1\nfor a in \"$@\"; do [ \"$a\" = push ] && { echo PUSHED; exit 0; }; done\nexec #{real_git} \"$@\"\n"
    )

    File.chmod!(fake_git, 0o755)

    for args <- [["init", "--quiet", "-b", "aiur/4200-x"], ["remote", "add", "origin", "https://github.com/owner/repo.git"]] do
      assert {_, 0} = System.cmd(real_git, ["-C", workspace | args], stderr_to_stdout: true)
    end

    {:ok, workspace: workspace, git: Path.join(bin, "git"), fake_git: fake_git}
  end

  defp push(context, state, args \\ ["origin", "HEAD"], ticket_state \\ "agent:in-progress") do
    System.cmd(context.git, ["-C", context.workspace, "push" | args],
      env: [{"AIUR_REAL_GIT", context.fake_git}, {"AIUR_AGENT_WORKSPACE", context.workspace}, {"FAKE_QUEUE_STATE", state}, {"FAKE_TICKET_STATE", ticket_state}],
      stderr_to_stdout: true
    )
  end

  test "refuses a push to a pull request that is in the merge queue", context do
    for args <- [["origin", "HEAD"], [], ["origin", "+aiur/4200-x"], ["origin", "HEAD:refs/heads/aiur/4200-x"]] do
      assert {output, 64} = push(context, "true MERGEABLE APPROVED", args)
      assert output =~ "is in the merge queue"
      refute output =~ "PUSHED"
    end
  end

  test "allows the push when the queued pull request is conflicting or has changes requested", context do
    assert {"PUSHED\n", 0} = push(context, "true CONFLICTING APPROVED")
    assert {"PUSHED\n", 0} = push(context, "true MERGEABLE CHANGES_REQUESTED")
  end

  test "allows pushes that cannot dequeue the pull request", context do
    assert {"PUSHED\n", 0} = push(context, "false MERGEABLE APPROVED")
    # No answer from GitHub: fail open rather than block every push.
    assert {"PUSHED\n", 0} = push(context, "")
    # A rescue ref is not the pull request's head branch.
    assert {"PUSHED\n", 0} = push(context, "true MERGEABLE APPROVED", ["origin", "HEAD:refs/heads/rescue/4200"])
  end

  test "refuses pushes while the ticket is handed off and allows review rework", context do
    for state <- ["agent:human-review", "agent:ci-wait"] do
      assert {output, 64} = push(context, "false MERGEABLE APPROVED", ["origin", "HEAD"], state)
      assert output =~ "ticket #4200 is handed off"
      refute output =~ "PUSHED"
    end

    assert {"PUSHED\n", 0} = push(context, "false MERGEABLE APPROVED", ["origin", "HEAD"], "agent:rework")
  end
end
