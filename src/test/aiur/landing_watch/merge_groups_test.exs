defmodule Aiur.LandingWatch.MergeGroupsTest do
  use ExUnit.Case, async: true

  alias Aiur.LandingWatch.MergeFailureClassifier
  alias Aiur.LandingWatch.MergeGroups

  test "only active merge-group runs without a live PR entry are cancelled" do
    parent = self()

    runs = [
      %{"id" => 31, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-3-aaa"},
      %{"id" => 32, "event" => "merge_group", "status" => "queued", "head_branch" => "gh-readonly-queue/main/pr-4-bbb"},
      %{"id" => 33, "event" => "merge_group", "status" => "completed", "head_branch" => "gh-readonly-queue/main/pr-5-ccc"},
      %{"id" => 34, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-3-aaa-pr-4-bbb"}
    ]

    request = fn
      %{method: :get} ->
        {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}

      %{method: :post, url: url} ->
        send(parent, {:cancel, url})
        {:ok, %{status: 202, body: %{}}}
    end

    observations = [%{number: 3, base: "main", merge_queue_entry: %{"id" => "entry-3"}}]

    assert :ok = MergeGroups.cancel_stale(observations, base_branch: "main", request_fun: request, live_observations_fun: fn _, _ -> {:ok, observations} end)
    assert_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/32/cancel"}
    assert_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/34/cancel"}
    refute_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/31/cancel"}
  end

  test "an active run built before the currently queued PR head is cancelled" do
    parent = self()

    runs = [
      %{"id" => 41, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-3-aaa", "created_at" => "2026-10-13T23:59:00Z"},
      %{"id" => 42, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-3-aaa", "created_at" => "2026-10-14T00:01:00Z"}
    ]

    request = fn
      %{method: :get} ->
        {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}

      %{method: :post, url: url} ->
        send(parent, {:cancel, url})
        {:ok, %{status: 202, body: %{}}}
    end

    observations = [
      %{number: 3, base: "main", head: "head-current", head_committed_at: "2026-10-14T00:00:00Z", merge_queue_entry: %{"id" => "entry-new", "pullRequest" => %{"headRefOid" => "head-current"}}}
    ]

    assert :ok = MergeGroups.cancel_stale(observations, base_branch: "main", request_fun: request, live_observations_fun: fn _, _ -> {:ok, observations} end)
    assert_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/41/cancel"}
    refute_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/42/cancel"}
  end

  test "the stale-run census queries active and completed statuses separately" do
    parent = self()
    historical = Enum.map(1..501, &%{"id" => &1, "event" => "merge_group", "status" => "completed", "head_branch" => "gh-readonly-queue/main/pr-#{&1}-old"})

    request = fn
      %{method: :get, url: url} ->
        send(parent, {:census, url})

        runs =
          if String.contains?(url, "status=in_progress"),
            do: [%{"id" => 900, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-900-old"}],
            else: historical

        {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}

      %{method: :post, url: url} ->
        send(parent, {:cancel, url})
        {:ok, %{status: 202, body: %{}}}
    end

    assert :ok = MergeGroups.cancel_stale([], base_branch: "main", request_fun: request, live_observations_fun: fn _, _ -> {:ok, []} end)

    urls =
      for _ <- 1..5 do
        assert_received {:census, url}
        url
      end

    assert Enum.all?(urls, &String.contains?(&1, "event=merge_group"))
    assert Enum.any?(urls, &String.contains?(&1, "status=queued"))
    assert Enum.any?(urls, &String.contains?(&1, "status=in_progress"))
    assert Enum.any?(urls, &String.contains?(&1, "status=waiting"))
    assert Enum.any?(urls, &String.contains?(&1, "status=requested"))
    assert Enum.any?(urls, &String.contains?(&1, "status=completed"))
    assert_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/900/cancel"}
    refute_received {:cancel, "https://api.github.com/repos/test-org/test-repo/actions/runs/501/cancel"}
  end

  test "queue is re-observed after the active-run census before cancelling" do
    parent = self()
    runs = [%{"id" => 91, "event" => "merge_group", "status" => "in_progress", "head_branch" => "gh-readonly-queue/main/pr-9-abc", "created_at" => "2026-10-14T00:01:00Z"}]

    request = fn
      %{method: :get} ->
        {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}

      %{method: :post, url: url} ->
        send(parent, {:cancel, url})
        {:ok, %{status: 202, body: %{}}}
    end

    newly_enqueued = [%{number: 9, base: "main", head: "head-now", head_committed_at: "2026-10-14T00:00:00Z", merge_queue_entry: %{"id" => "entry", "pullRequest" => %{"headRefOid" => "head-now"}}}]

    assert :ok = MergeGroups.cancel_stale([], base_branch: "main", request_fun: request, live_observations_fun: fn _, _ -> {:ok, newly_enqueued} end)
    refute_received {:cancel, _}
  end

  test "a test failure in a group with no observed dropped PR is classified without a requeue" do
    failed = group_run(101, "failure", "pr-17-a-pr-19-b")
    passed = group_run(102, "success", "pr-17-a-pr-21-c")

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [failed, passed], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    assert :ok =
             MergeGroups.cancel_stale([],
               base_branch: "main",
               request_fun: request,
               live_observations_fun: fn _, _ -> {:ok, []} end,
               job_log_fun: fn _, _ -> {:ok, "failed test ExampleTest regression"} end,
               jobs_fun: fn
                 101, _ -> {:ok, [%{"name" => "test", "conclusion" => "failure", "check_run_url" => "https://api.github.com/repos/o/r/check-runs/901"}]}
                 102, _ -> {:ok, [%{"name" => "test", "conclusion" => "success"}]}
               end,
               known_failure_patterns: []
             )
  end

  test "a completed failed run is fetched once across repeated polls" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-run-journal-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(journal) end)
    failed = group_run(111, "failure", "pr-17-a")

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [failed], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    options = [
      base_branch: "main",
      request_fun: request,
      journal_path: journal,
      live_observations_fun: fn _, _ -> {:ok, []} end,
      job_log_fun: fn _, _ -> {:ok, "failed test ExampleTest regression"} end,
      jobs_fun: fn id, _ ->
        send(parent, {:jobs, id})
        {:ok, [%{"name" => "test", "conclusion" => if(id == 111, do: "failure", else: "success"), "check_run_url" => "https://api.github.com/repos/o/r/check-runs/901"}]}
      end,
      known_failure_patterns: []
    ]

    assert :ok = MergeGroups.cancel_stale([], options)
    assert_received {:jobs, 111}
    assert :ok = MergeGroups.cancel_stale([], options)
    refute_received {:jobs, _}
  end

  test "a processing error releases the completed-run claim for the next poll" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-retry-journal-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(journal) end)
    failed = group_run(121, "failure", "pr-17-a")
    calls = :atomics.new(1, [])

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [failed], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    options = [
      base_branch: "main",
      request_fun: request,
      journal_path: journal,
      live_observations_fun: fn _, _ -> {:ok, []} end,
      jobs_fun: fn 121, _ ->
        send(parent, :jobs_requested)

        if :atomics.add_get(calls, 1, 1) == 1 do
          {:error, :temporary_failure}
        else
          {:ok, [%{"name" => "test", "conclusion" => "failure", "check_run_url" => "https://api.github.com/repos/o/r/check-runs/902"}]}
        end
      end,
      job_log_fun: fn _, _ -> {:ok, "failed test ExampleTest regression"} end
    ]

    assert {:error, _} = MergeGroups.cancel_stale([], options)
    assert_received :jobs_requested
    assert :ok = MergeGroups.cancel_stale([], options)
    assert_received :jobs_requested
  end

  test "a recorded known non-PR failure re-enqueues the dropped approved PR once" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-flake-#{System.unique_integer([:positive])}.json")
    failed = group_run(201, "failure", "pr-17-a")
    passed = group_run(202, "success", "pr-17-b")

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [failed, passed], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    pr = %{
      number: 17,
      base: "main",
      head: "current",
      node_id: "PR_17",
      draft?: false,
      review_decision: "APPROVED",
      merge_queue_entry: nil,
      auto_merge_request: nil,
      rest: %{"head" => %{"ref" => "aiur/17-work"}}
    }

    options = [
      base_branch: "main",
      request_fun: request,
      journal_path: journal,
      live_observations_fun: fn _, _ -> {:ok, [pr]} end,
      job_log_fun: fn _, _ -> {:ok, "mix test src/test/aiur/example_test.exs:12 failed"} end,
      jobs_fun: fn id, _ -> {:ok, [%{"name" => "test", "conclusion" => if(id == 201, do: "failure", else: "success"), "check_run_url" => "https://api.github.com/repos/o/r/check-runs/901"}]} end,
      known_failure_patterns: ["example_test.exs"],
      changed_paths_fun: fn _, _ -> {:ok, ["src/lib/changed.ex"]} end,
      approved_fun: fn _, _ -> {:ok, true} end,
      revalidate_fun: fn _, _, _ -> :ok end,
      attribution_fun: fn _ -> {:ok, :clean} end,
      comment_fun: fn _, _, _ -> :ok end,
      enqueue_fun: fn node, head, _ ->
        send(parent, {:enqueue, node, head})
        {:ok, "entry-17"}
      end
    ]

    assert :ok = MergeGroups.cancel_stale([], options)
    assert_received {:enqueue, "PR_17", "current"}
    assert :ok = MergeGroups.cancel_stale([], options)
    refute_received {:enqueue, _, _}
    File.rm(journal)
  end

  test "the fourth group requeue in fifteen minutes is not enqueued" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-rate-cap-#{System.unique_integer([:positive])}.json")
    run = group_run(401, "failure", "pr-17-a-pr-18-b-pr-19-c-pr-20-d")

    prs =
      for number <- 17..20,
          do: %{
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

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [run], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    options = [
      base_branch: "main",
      request_fun: request,
      journal_path: journal,
      now_ms: 2_000_000,
      live_observations_fun: fn _, _ -> {:ok, prs} end,
      job_log_fun: fn _, _ -> {:ok, "runner lost before job setup"} end,
      jobs_fun: fn _, _ -> {:ok, [%{"id" => 12, "name" => "ci gate", "conclusion" => "failure"}]} end,
      approved_fun: fn _, _ -> {:ok, true} end,
      revalidate_fun: fn _, _, _ -> :ok end,
      attribution_fun: fn _ -> {:ok, :clean} end,
      comment_fun: fn _, _, _ -> :ok end,
      enqueue_fun: fn node, head, _ ->
        send(parent, {:enqueue, node, head})
        {:ok, "entry-#{head}"}
      end
    ]

    assert :ok = MergeGroups.cancel_stale([], options)

    enqueued =
      for _ <- 1..3 do
        assert_received {:enqueue, node, _}
        node
      end

    assert length(enqueued) == 3
    assert :ok = MergeGroups.cancel_stale([], options)
    refute_received {:enqueue, _, _}
    assert {:ok, %{"1970-01-01T00:00:00Z" => 3}} = journal_counts(journal)
    File.rm(journal)
  end

  test "recorded coverage shard cascade and browser cancellation classify as infrastructure" do
    coverage = fixture("run-38746066535-coverage.log")
    browser = fixture("run-38742645458-browser.log")

    assert {:ok, {:infra, _}} =
             MergeFailureClassifier.classify(group_run(301, "failure", "pr-17-a"), [%{"name" => "coverage (4/4)", "conclusion" => "failure"}], [], job_log_fun: fn _, _ -> {:ok, coverage} end)

    assert {:ok, {:infra, _}} =
             MergeFailureClassifier.classify(group_run(302, "failure", "pr-17-a"), [%{"name" => "browser smoke (3/3)", "conclusion" => "cancelled"}], [], job_log_fun: fn _, _ -> {:ok, browser} end)

    assert String.contains?(fixture("run-38729249620-browser.log"), "The operation was canceled")
  end

  test "recorded inherited ci gate failure is classified separately from PR test failures" do
    log = fixture("run-38742654941-inherited.log")
    jobs = [%{"name" => "ci gate", "conclusion" => "failure", "needs_json" => ~s({"workflow-security":{"result":"failure"},"lint":{"result":"success"}})}]

    assert {:ok, {:inherited, _}} =
             MergeFailureClassifier.classify(group_run(303, "failure", "pr-17-a"), jobs, [], job_log_fun: fn _, _ -> {:ok, log} end)
  end

  test "known failure in untouched file is non-PR while a touched-file failure stays PR-caused" do
    log = "mix test src/test/aiur/example_test.exs:12 failed"
    run = group_run(304, "failure", "pr-17-a")
    jobs = [%{"name" => "test", "conclusion" => "failure"}]

    opts = [
      job_log_fun: fn _, _ -> {:ok, log} end,
      known_failure_patterns: ["example_test.exs"],
      changed_paths_fun: fn _, _ -> {:ok, ["src/lib/changed.ex"]} end,
      changed_paths_by_pr: %{17 => ["src/lib/changed.ex"]}
    ]

    assert {:ok, {:known_non_pr, _}} = MergeFailureClassifier.classify(run, jobs, [], opts)
    touched_opts = Keyword.put(opts, :changed_paths_by_pr, %{17 => ["src/test/aiur/example_test.exs"]})
    assert {:ok, {:pr_caused, _}} = MergeFailureClassifier.classify(run, jobs, [], touched_opts)
    main_failure_opts = opts |> Keyword.put(:known_failure_patterns, []) |> Keyword.put(:failed_on_main_fun, fn _, _ -> true end)
    assert {:ok, {:known_non_pr, _}} = MergeFailureClassifier.classify(run, jobs, [], main_failure_opts)
  end

  test "a test failure in a PR-touched file routes to rework with its run URL" do
    parent = self()
    journal = Path.join(System.tmp_dir!(), "landing-watch-pr-failure-#{System.unique_integer([:positive])}.json")
    run = group_run(305, "failure", "pr-17-a")

    request = fn %{method: :get, url: url} ->
      runs = if String.contains?(url, "status=completed"), do: [run], else: []
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}}}
    end

    pr = %{
      number: 17,
      base: "main",
      head: "current",
      node_id: "PR_17",
      draft?: false,
      review_decision: "APPROVED",
      merge_queue_entry: nil,
      auto_merge_request: nil,
      rest: %{"head" => %{"ref" => "aiur/17-work"}}
    }

    options = [
      base_branch: "main",
      request_fun: request,
      journal_path: journal,
      live_observations_fun: fn _, _ -> {:ok, [pr]} end,
      job_log_fun: fn _, _ -> {:ok, "mix test src/test/aiur/changed_test.exs:12 failed"} end,
      jobs_fun: fn _, _ -> {:ok, [%{"id" => 901, "name" => "test", "conclusion" => "failure"}]} end,
      changed_paths_fun: fn _, _ -> {:ok, ["src/test/aiur/changed_test.exs"]} end,
      known_failure_patterns: [],
      repo_fun: fn -> {:ok, {"aiur-team", "aiur"}} end,
      rework_fun: fn observation, failures, opts ->
        send(parent, {:rework, observation.number, failures, Keyword.fetch!(opts, :run_url)})
        :ok
      end,
      enqueue_fun: fn _, _, _ ->
        send(parent, :unexpected_enqueue)
        {:ok, "entry"}
      end
    ]

    assert :ok = MergeGroups.cancel_stale([], options)
    assert_received {:rework, 17, [%{name: "test", excerpt: excerpt}], "https://github.com/aiur-team/aiur/actions/runs/305"}
    assert String.contains?(excerpt, "changed_test.exs")
    refute_received :unexpected_enqueue
    File.rm(journal)
  end

  defp group_run(id, conclusion, prs) do
    %{"id" => id, "event" => "merge_group", "status" => "completed", "conclusion" => conclusion, "head_branch" => "gh-readonly-queue/main/#{prs}"}
  end

  defp fixture(name), do: Path.join([__DIR__, "../../fixtures/landing_watch", name]) |> Path.expand() |> File.read!()

  defp journal_counts(path) do
    alias Aiur.LandingWatch.Journal
    Journal.merge_group_requeues_by_hour(journal_path: path)
  end
end
