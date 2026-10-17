defmodule Aiur.LandingWatch.MergeGroupJobLogUnavailableTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.MergeGroups

  test "an unreadable job log raises an attention for that run and keeps routing the rest" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-job-log-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(journal) end)

    unreadable = group_run(501, "pr-17-a")
    readable = group_run(502, "pr-18-b")

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [unreadable, readable], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    options = [
      base_branch: "main",
      token: "test-gh-token",
      request_fun: request,
      journal_path: journal,
      live_observations_fun: fn _, _ -> {:ok, [pr(17), pr(18)]} end,
      jobs_fun: fn run_id, _ -> {:ok, [%{"id" => run_id * 10, "name" => "test", "conclusion" => "failure"}]} end,
      job_log_fun: fn
        %{"id" => 5010}, _ -> {:error, :not_found}
        _, _ -> {:ok, "mix test src/test/aiur/changed_test.exs:12 failed"}
      end,
      changed_paths_fun: fn _, _ -> {:ok, ["src/test/aiur/changed_test.exs"]} end,
      known_failure_patterns: [],
      repo_fun: fn -> {:ok, {"aiur-team", "aiur"}} end,
      alert_emitter: fn name, opts -> send(parent, {:alert, name, opts}) end,
      rework_fun: fn observation, _failures, _opts ->
        send(parent, {:rework, observation.number})
        :ok
      end
    ]

    assert :ok = MergeGroups.cancel_stale([], options)

    assert_received {:alert, "system.pr.landing.job_log_unavailable", alert}
    assert alert[:needs_attention]
    assert alert[:message] =~ "job 5010"
    assert alert[:message] =~ "run 501"
    assert_received {:rework, 18}
    refute_received {:rework, 17}

    # The degraded run stays claimed, so the next poll neither retries nor re-alerts it.
    assert :ok = MergeGroups.cancel_stale([], options)
    refute_received {:alert, _, _}
  end

  defp group_run(id, prs) do
    %{
      "id" => id,
      "event" => "merge_group",
      "status" => "completed",
      "conclusion" => "failure",
      "head_branch" => "gh-readonly-queue/main/#{prs}"
    }
  end

  defp pr(number) do
    %{
      number: number,
      base: "main",
      head: "current",
      node_id: "PR_#{number}",
      draft?: false,
      review_decision: "APPROVED",
      merge_queue_entry: nil,
      auto_merge_request: nil,
      rest: %{"head" => %{"ref" => "aiur/#{number}-work"}}
    }
  end
end
