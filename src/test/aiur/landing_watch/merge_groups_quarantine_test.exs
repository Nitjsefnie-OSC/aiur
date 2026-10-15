defmodule Aiur.LandingWatch.MergeGroupsQuarantineTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.MergeGroups

  test "two failed runs from unrelated PRs open one quarantine PR candidate" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "merge-group-quarantine-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(journal) end)

    runs = [
      failed_run(501, "pr-41-a-pr-42-b", "https://github.com/test-org/test-repo/actions/runs/501", "2026-10-15T10:00:00Z"),
      failed_run(502, "pr-43-c-pr-44-d", "https://github.com/test-org/test-repo/actions/runs/502", "2026-10-15T10:10:00Z")
    ]

    request = fn %{method: :get, url: url} ->
      if String.contains?(url, "status=completed"),
        do: {:ok, %{status: 200, body: %{"workflow_runs" => runs}}},
        else: {:ok, %{status: 200, body: %{"workflow_runs" => []}}}
    end

    opts = [
      base_branch: "main",
      journal_path: journal,
      request_fun: request,
      live_observations_fun: fn _fallback, _opts -> {:ok, []} end,
      changed_paths_fun: fn _pr, _opts -> {:ok, []} end,
      jobs_fun: fn _run, _opts -> {:ok, [%{"check_run_id" => 1, "name" => "test", "conclusion" => "failure"}]} end,
      annotations_fun: fn _id, _opts -> {:ok, [%{"title" => "aiur-test-failure", "message" => "new-failure :: Aiur.ExampleTest :: flakes", "path" => "src/test/example_test.exs"}]} end,
      flake_recorder: fn _failure, _run, _passed, recorder_opts ->
        send(parent, :flake_ticket_recorded)
        recorder_opts[:issue_recorded_fun].(900)
      end,
      quarantine_pr_fun: fn candidate, ticket, _opts ->
        send(parent, {:quarantine_candidate, ticket, candidate})
        {:ok, %{number: 901}}
      end,
      cancel_fun: fn _, _ -> :ok end
    ]

    assert :ok = MergeGroups.cancel_stale([], opts)
    assert_received :flake_ticket_recorded
    assert_received {:quarantine_candidate, 900, candidate}
    assert candidate.identity == "Aiur.ExampleTest :: flakes"
    assert Enum.map(candidate.observations, & &1.pr) |> Enum.uniq() |> length() == 4
  end

  defp failed_run(id, branch, url, created_at) do
    %{
      "id" => id,
      "event" => "merge_group",
      "conclusion" => "failure",
      "head_branch" => "gh-readonly-queue/main/#{branch}",
      "html_url" => url,
      "created_at" => created_at
    }
  end
end
