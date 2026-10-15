defmodule Aiur.ExecutorSweep.SnapshotCache do
  @moduledoc "Reads the current repository's already-cached GitHub resources."

  alias Aiur.GitHub.{Config, ResourceStore}

  @spec read() :: map()
  def read do
    with repo when is_binary(repo) <- Config.repo(),
         [owner, name] <- String.split(repo, "/", parts: 2) do
      pull_requests = entries(:pull_request, owner, name)
      branch_pull_requests = entries(:branch_pull_request, owner, name)
      reviews = entries(:pull_request_reviews, owner, name)
      tickets = entries(:issue_labels, owner, name)
      issues = Map.new(entries(:issue, owner, name))
      blocked_by = Map.new(entries(:issue_blocked_by, owner, name))
      timelines = Map.new(entries(:issue_timeline, owner, name))
      snapshot = build(pull_requests, reviews, tickets, issues, blocked_by, branch_pull_requests, timelines)
      local = local_snapshot()
      snapshot = Map.merge(snapshot, local)

      pull_requests = Enum.map(snapshot.pull_requests, &attach_ci(&1, local.ci_wait))

      snapshot
      |> Map.put(:pull_requests, pull_requests)
      |> Map.put(:merge_queue, merge_queue_entries(pull_requests))
    else
      _ -> Map.merge(%{pull_requests: [], tickets: []}, local_snapshot())
    end
  end

  defp local_snapshot do
    decisions =
      if Process.whereis(Aiur.DecisionStore) do
        Aiur.DecisionStore.list()
        |> Enum.map(fn decision ->
          %{id: decision.decision_id, blocking: decision.blocking, status: Atom.to_string(decision.decision_status), created_at: decision.created_at}
        end)
      else
        []
      end

    queue = Aiur.BuildQueue.show()
    {fleet, dispatcher_service} = fleet_snapshot()
    queues = Map.get(queue, :queues, [])
    focus = focus_queue(queues, fleet)

    %{
      decisions: decisions,
      queue_sets: Enum.map(queues, &%{id: &1.queue_id, held: &1.held}),
      idle_slots: idle_slots(fleet),
      focus_set: focus,
      ci_wait: Map.get(fleet, :ci_wait, []),
      services: watcher_services() ++ List.wrap(dispatcher_service)
    }
  rescue
    _ -> %{decisions: [], queue_sets: [], idle_slots: 0, focus_set: nil, ci_wait: [], services: []}
  end

  defp fleet_snapshot do
    case Aiur.Orchestrator.fleet_view(Aiur.Orchestrator, 2_000) do
      {:ok, snapshot, _freshness} -> {snapshot, nil}
      _ -> {%{}, %{name: "dispatcher", status: "stalled"}}
    end
  catch
    :exit, _ -> {%{}, %{name: "dispatcher", status: "stalled"}}
  end

  defp watcher_services do
    ([watcher_service("landing watcher", safe_state(&Aiur.LandingWatch.state/0))] ++
       if(Aiur.MainWatch.enabled?(), do: [watcher_service("default-branch watcher", safe_state(&Aiur.MainWatch.state/0))], else: []))
    |> Enum.reject(&is_nil/1)
  rescue
    _ -> []
  end

  defp safe_state(fun) do
    fun.()
  rescue
    _ -> %{watcher: :unavailable}
  catch
    :exit, _ -> %{watcher: :unavailable}
  end

  defp watcher_service(name, %{watcher: :running} = state) do
    cond do
      not is_nil(value(state, :last_error, nil)) -> %{name: name, status: "down"}
      is_integer(value(state, :last_poll_at_ms, nil)) and System.system_time(:millisecond) - value(state, :last_poll_at_ms, 0) > 15 * 60_000 -> %{name: name, status: "stalled"}
      true -> nil
    end
  end

  defp watcher_service(name, %{watcher: status}) when status in [:unavailable, :not_running], do: %{name: name, status: "down"}
  defp watcher_service(name, _), do: %{name: name, status: "down"}

  defp idle_slots(%{capacity: capacity, running: running}) when is_integer(capacity) and is_list(running),
    do: max(capacity - length(running), 0)

  defp idle_slots(_), do: 0

  defp focus_queue([], _fleet), do: nil

  defp focus_queue(queues, fleet) do
    queue = Enum.min_by(queues, &Map.get(&1, :set_rank, 0))
    claimed = fleet |> Map.get(:running, []) |> Enum.map(&value(&1, :identifier, nil)) |> MapSet.new()
    startable = Enum.filter(queue.items, &(value(&1, :state, nil) in [:ready, :promoted, :overridden] and value(&1, :verdict, nil) == :ready))

    %{
      id: queue.queue_id,
      startable_count: length(startable),
      claimed_count: Enum.count(startable, &MapSet.member?(claimed, to_string(value(&1, :number, ""))))
    }
  end

  defp attach_ci(pr, ci_wait) do
    case Enum.find(ci_wait, fn ci ->
           (value(ci, :pr_number, nil) == pr.number or value(ci, :identifier, nil) == to_string(pr.issue_number)) and
             value(ci, :head_sha, nil) == pr.head_sha
         end) do
      nil ->
        pr

      ci ->
        failures = value(ci, :failures, [])
        required = Enum.map(failures, &%{name: value(&1, :name, "required check"), conclusion: value(&1, :result, value(&1, :conclusion, nil))})
        Map.merge(pr, %{required_checks: required, failure_class: to_string(value(ci, :failure_class, "unknown"))})
    end
  end

  defp merge_queue_entries(pull_requests) do
    pull_requests
    |> Enum.filter(& &1.in_merge_queue)
    |> Enum.map(fn pr -> %{number: pr.number, mergeable: if(pr.mergeable == "CONFLICTING", do: "UNMERGEABLE", else: pr.mergeable)} end)
  end

  @doc false
  @spec build([{integer(), map()}], [{integer(), list()}], [{integer(), list()}], map(), map(), [{integer(), map()}], map()) :: map()
  def build(pull_requests, reviews, tickets, issues \\ %{}, blocked_by \\ %{}, branch_pull_requests \\ [], timelines \\ %{}) do
    reviews = Map.new(reviews)
    branch_prs = Map.new(branch_pull_requests)
    pull_requests = merge_pr_sources(pull_requests, branch_pull_requests)

    pull_requests =
      Enum.map(pull_requests, &normalize_snapshot_pr(&1, reviews, branch_prs, timelines))
      |> Enum.reject(&is_nil/1)

    %{
      pull_requests: pull_requests,
      merge_queue: merge_queue_entries(pull_requests),
      tickets: Enum.map(tickets, &normalize_ticket(&1, issues, blocked_by))
    }
  end

  defp normalize_ticket({number, labels}, issues, blocked_by) do
    issue = Map.get(issues, number, %{})
    blockers = Map.get(blocked_by, number, [])
    blockers = if is_list(blockers), do: blockers, else: []
    closed? = fn blocker -> value(Map.get(issues, value(blocker, "number", nil), %{}), "state", "") == "closed" end

    %{
      number: number,
      labels: labels,
      created_at: value(issue, "created_at", nil),
      open_blocked_by: Enum.reject(blockers, closed?),
      closed_blockers: blockers |> Enum.filter(closed?) |> Enum.map(&value(&1, "number", nil))
    }
  end

  defp merge_pr_sources(pull_requests, branch_pull_requests) do
    direct = Map.new(pull_requests)

    Enum.reduce(branch_pull_requests, direct, fn {_ticket, pr}, acc ->
      case positive_number(value(pr, "number", nil)) do
        nil -> acc
        number -> Map.update(acc, number, pr, &Map.merge(&1, pr))
      end
    end)
    |> Enum.to_list()
  end

  defp normalize_snapshot_pr({number, pr}, reviews, branch_prs, timelines) do
    case normalize_pr(number, pr, reviews) do
      nil ->
        nil

      normalized ->
        case Map.get(branch_prs, normalized.issue_number) do
          nil -> normalized
          branch_pr -> attach_branch_metadata(normalized, branch_pr, Map.get(timelines, number))
        end
    end
  end

  defp attach_branch_metadata(normalized, branch_pr, timeline) do
    metadata = normalize_branch_metadata(branch_pr) |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()
    normalized = Map.merge(normalized, metadata)
    Map.put(normalized, :ready_at, timeline_ready_at(timeline, normalized))
  end

  defp positive_number(number) when is_integer(number) and number > 0, do: number

  defp positive_number(number) when is_binary(number) do
    case Integer.parse(number) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> nil
    end
  end

  defp positive_number(_), do: nil

  defp normalize_branch_metadata(pr) do
    merge_queue = value(pr, "mergeQueueEntry", nil)
    auto_merge = value(pr, "autoMergeRequest", false)

    %{
      review_decision: value(pr, "review_decision", nil),
      approved_head_sha: value(pr, "approved_head_sha", nil),
      reviewed_head_sha: value(pr, "reviewed_head_sha", nil),
      in_merge_queue: not is_nil(merge_queue),
      auto_merge: auto_merge not in [nil, false],
      mergeable: value(pr, "mergeable", nil),
      ready_at: timestamp(value(pr, "ready_for_review_at", nil)) || timestamp(value(pr, "created_at", nil))
    }
  end

  defp timeline_ready_at(%{"events" => events}, pr) when is_list(events) do
    events
    |> Enum.filter(&(value(&1, "event", "") == "ready_for_review"))
    |> Enum.max_by(&value(&1, "created_at", ""), fn -> nil end)
    |> case do
      %{} = event -> timestamp(value(event, "created_at", nil))
      nil -> pr.ready_at
    end
  end

  defp timeline_ready_at(_timeline, pr), do: pr.ready_at

  @spec entries(atom(), String.t(), String.t()) :: [{integer(), map()}]
  defp entries(type, owner, repo) do
    type
    |> ResourceStore.list(owner, repo)
    |> Enum.flat_map(fn {{^type, _owner, _repo, id}, %{data: data}} ->
      case Integer.parse(to_string(id)) do
        {number, ""} when is_map(data) or is_list(data) -> [{number, data}]
        _ -> []
      end
    end)
  end

  defp normalize_pr(number, pr, reviews) when is_map(pr) do
    head = value(pr, "head", %{})
    sha = value(head, "sha", nil)
    branch = value(head, "ref", "")
    issue_number = issue_number(branch)
    review_rows = Map.get(reviews, number, [])
    reviewed = Enum.any?(review_rows, &(value(&1, "commit_id", nil) == sha))
    approved = Enum.any?(review_rows, &(value(&1, "commit_id", nil) == sha and value(&1, "state", "") == "APPROVED"))

    %{
      number: number,
      issue_number: issue_number,
      state: value(pr, "state", "closed"),
      draft: value(pr, "draft", false),
      head_sha: sha,
      reviewed_head_sha: if(reviewed, do: sha),
      approved_head_sha: value(pr, "approved_head_sha", nil) || if(approved, do: sha),
      ready_at: timestamp(value(pr, "ready_for_review_at", nil)) || timestamp(value(pr, "created_at", nil)),
      review_decision: value(pr, "review_decision", nil) || if(approved, do: "APPROVED", else: ""),
      in_merge_queue: not is_nil(value(pr, "mergeQueueEntry", value(pr, "merge_queue_entry", nil))),
      auto_merge: value(pr, "autoMergeRequest", value(pr, "auto_merge", false)) not in [nil, false],
      required_checks: value(pr, "required_checks", []),
      mergeable: value(pr, "mergeable", nil),
      failure_class: value(pr, "failure_class", "unknown")
    }
  end

  defp normalize_pr(_number, _pr, _reviews), do: nil

  defp issue_number(branch) do
    case Regex.run(~r/(?:^|\/)aiur\/(\d+)(?:-|$)/, branch) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp timestamp(_), do: nil

  defp value(map, key, default) do
    Map.get(map, key, Map.get(map, String.to_atom(key), default))
  end
end
