defmodule Aiur.LandingWatch.MergeGroupBlameTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.Journal
  alias Aiur.LandingWatch.MergeGroups

  test "only the PR touching the failing test is sent to rework" do
    parent = self()
    path = Path.join(System.tmp_dir!(), "merge-group-blame-#{System.unique_integer([:positive])}.json")

    run = %{
      "id" => 908,
      "event" => "merge_group",
      "status" => "completed",
      "conclusion" => "failure",
      "head_branch" => "gh-readonly-queue/main/pr-17-a-pr-18-b-pr-19-c"
    }

    request = fn %{url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [run], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    prs =
      for number <- 17..19 do
        %{
          number: number,
          base: "main",
          head: "head-#{number}",
          node_id: "PR_#{number}",
          draft?: false,
          review_decision: "APPROVED",
          merge_queue_entry: nil,
          auto_merge_request: nil,
          rest: %{"head" => %{"ref" => "aiur/#{number}-work"}}
        }
      end

    opts = [
      base_branch: "main",
      token: "test-gh-token",
      request_fun: request,
      journal_path: path,
      live_observations_fun: fn _, _ -> {:ok, prs} end,
      jobs_fun: fn _, _ -> {:ok, [%{"id" => 910, "name" => "test", "conclusion" => "failure"}]} end,
      job_log_fun: fn _, _ ->
        {:ok, "mix test src/test/aiur/changed_test.exs:12 failed\nmix test src/test/aiur/second_changed_test.exs:8 failed"}
      end,
      changed_paths_fun: fn number, _ ->
        paths = ["src/test/aiur/changed_test.exs", "src/test/aiur/second_changed_test.exs"]
        {:ok, if(number == 18, do: paths, else: [])}
      end,
      recent_main_failure_paths_fun: fn _, _ -> {:ok, []} end,
      known_failure_patterns: [],
      rework_fun: fn observation, _, _ ->
        send(parent, {:rework, observation.number})
        :ok
      end,
      enqueue_fun: fn _, _, _ -> {:ok, "entry"} end,
      approved_fun: fn _, _ -> {:ok, true} end,
      revalidate_fun: fn _, _, _ -> :ok end,
      attribution_fun: fn _ -> {:ok, :clean} end,
      comment_fun: fn _, _, _ -> :ok end
    ]

    assert :ok = MergeGroups.cancel_stale([], opts)
    assert_received {:rework, 18}
    refute_received {:rework, 17}
    refute_received {:rework, 19}
    assert {:ok, rows} = Journal.failure_observations(journal_path: path)
    assert Enum.any?(rows, &(&1["identity"] == "merge-group-blame:908" and &1["decision"] == "pr_caused"))
    Aiur.TestCleanup.rm_rf!(path)
  end

  test "the journal counts repeated failures against the same PR head" do
    path = Path.join(System.tmp_dir!(), "merge-group-blame-attempt-#{System.unique_integer([:positive])}.json")
    opts = [journal_path: path]

    assert {:ok, 1} = Journal.record_merge_group_blame_attempt(18, "same-head", opts)
    assert {:ok, 2} = Journal.record_merge_group_blame_attempt(18, "same-head", opts)
    assert {:ok, 1} = Journal.record_merge_group_blame_attempt(18, "new-head", opts)

    Aiur.TestCleanup.rm_rf!(path)
  end
end
