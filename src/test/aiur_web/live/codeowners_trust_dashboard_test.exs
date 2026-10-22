defmodule AiurWeb.CodeownersTrustDashboardTest do
  use Aiur.TestSupport
  require Phoenix.LiveViewTest

  alias Aiur.GitHub.CodeOwners

  @moduletag :tmp_dir

  test "dashboard reads degraded trust with age and clears it after recovery", %{tmp_dir: root} do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "github", tracker_repo: "owner/repo")
    path = Path.join(root, "CODEOWNERS")
    File.write!(path, "* @acme/team\n")
    previous = Process.whereis(CodeOwners)
    if previous, do: Process.unregister(CodeOwners)
    # The CodeOwners server resolves teams with the configured token.
    token_key = {Aiur.GitHub.Access.Token, :resolved_token}
    previous_token = :persistent_term.get(token_key, :unset)
    :persistent_term.put(token_key, "test-gh-token")
    on_exit(fn -> if previous_token == :unset, do: :persistent_term.erase(token_key), else: :persistent_term.put(token_key, previous_token) end)

    on_exit(fn ->
      if previous && Process.alive?(previous), do: Process.register(previous, CodeOwners)
    end)

    server =
      start_supervised!({CodeOwners, name: nil, path: path, request_fun: fn _ -> {:ok, %{status: 503, body: %{}}} end, alert_fun: fn _, _, _ -> :ok end, refresh_seconds: 86_400})

    assert CodeOwners.trust_snapshot(server).degradation.cause ==
             {:team_lookup_failed, "@acme/team", {:github, :http, %{status: 503}}}

    html =
      Phoenix.LiveViewTest.render_component(&AiurWeb.OperatorControlCenter.CodeownersTrust.banner/1,
        now: DateTime.utc_now(),
        snapshot: CodeOwners.trust_snapshot(server)
      )

    assert html =~ "Team lookup failed for @acme/team"
    assert html =~ "503"
    assert html =~ ~r/age \d+s/
    File.write!(path, "* @direct\n")
    CodeOwners.refresh(server)
    recovered = CodeOwners.trust_snapshot(server)
    assert Phoenix.LiveViewTest.render_component(&AiurWeb.OperatorControlCenter.CodeownersTrust.banner/1, now: DateTime.utc_now(), snapshot: recovered) == ""
  end
end
