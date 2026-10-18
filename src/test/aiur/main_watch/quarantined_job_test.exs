defmodule Aiur.MainWatch.QuarantinedJobTest do
  use Aiur.TestSupport
  alias Aiur.MainWatch.{GitHub, State}

  setup do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(), tracker_kind: "github", tracker_repo: "owner/repo")
    :ok
  end

  test "non-blocking quarantine failure does not make successful main CI red or dispatch a fixer" do
    run = %{
      "id" => 15,
      "head_sha" => "quarantine-red",
      "head_branch" => "main",
      "event" => "push",
      "name" => "ci",
      "status" => "completed",
      "conclusion" => "success",
      "check_suite_id" => 1,
      "updated_at" => "2026-10-10T00:00:00Z",
      "html_url" => "https://example.test/15"
    }

    blocking = check(1, "test", "success")
    quarantine = check(2, "quarantined tests (non-blocking)", "failure")

    assert {:ok, %{observations: [observation]}} =
             GitHub.poll("main", ["ci"], token: "test-gh-token", request_fun: request([run], [blocking, quarantine]), actions_write: false)

    assert observation.checks == [%{name: "test", conclusion: "success"}]
    assert {%{status: :green}, []} = State.observe(State.new(), observation, observation.completed_at)

    only_quarantine = request([run], [check(1, "test", "success"), quarantine])
    assert {:ok, %{observations: [green]}} = GitHub.poll("main", ["ci"], token: "test-gh-token", request_fun: only_quarantine, actions_write: false)
    assert green.checks == [%{name: "test", conclusion: "success"}]
    assert {%{status: :green}, []} = State.observe(State.new(), green, green.completed_at)
  end

  defp request(runs, checks) do
    fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") -> ok([%{"sha" => "quarantine-red"}])
        String.contains?(url, "event=push") -> ok(%{"workflow_runs" => runs})
        String.contains?(url, "/actions/runs?") -> ok(%{"workflow_runs" => []})
        String.contains?(url, "/check-runs?") -> ok(%{"check_runs" => checks})
        String.ends_with?(url, "/status") -> ok(%{"statuses" => []})
        String.contains?(url, "/annotations?") -> ok([])
        String.contains?(url, "/contents/") -> ok(%{"encoding" => "base64", "content" => ""})
        String.contains?(url, "/issues?") -> ok([])
        true -> flunk("unexpected quarantine request #{url}")
      end
    end
  end

  defp check(id, name, conclusion),
    do: %{"id" => id, "name" => name, "check_suite" => %{"id" => 1}, "app" => %{"slug" => "github-actions"}, "status" => "completed", "conclusion" => conclusion}

  defp ok(body), do: {:ok, %{status: 200, body: body, headers: []}}
end
