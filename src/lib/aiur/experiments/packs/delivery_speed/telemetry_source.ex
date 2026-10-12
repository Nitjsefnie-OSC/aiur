defmodule Aiur.Experiments.Packs.DeliverySpeed.TelemetrySource do
  @moduledoc "The pack's only reader of live telemetry, retained boots and usage accounting."
  alias Aiur.Claude.Telemetry.UsageAdapter.Relationship
  alias Aiur.Experiments.Packs.DeliverySpeed.{BootWindow, Tokens}
  alias Aiur.Experiments.Sources.Common
  alias Aiur.RunTelemetry
  alias Aiur.RunTelemetry.{Dataset, Summaries}
  alias Aiur.Usage.Headless.Catalog
  alias Aiur.UsageEnvelope.RelationshipRegistry

  @spec load(map(), map()) :: {:ok, map()} | {:error, term()}
  def load(window, ctx) do
    if Map.get_lazy(ctx, :telemetry_enabled, &Aiur.Config.telemetry_enabled?/0) do
      load_enabled(window, ctx)
    else
      {:error, :telemetry_disabled}
    end
  end

  defp load_enabled(window, ctx) do
    boot = Map.get_lazy(ctx, :boot_id, &RunTelemetry.boot_id/0)
    {prior, unreadable?} = prior_datasets(boot, window, ctx)
    live = Dataset.build(Map.get_lazy(ctx, :telemetry_path, &RunTelemetry.telemetry_file/0))

    datasets =
      case live do
        {:ok, dataset} -> [dataset | prior]
        {:error, _reason} -> prior
      end

    if datasets == [] do
      {:error, :telemetry_missing}
    else
      dataset = Dataset.merge(datasets)
      records = Enum.filter(dataset.records, &(DateTime.compare(&1.timestamp, window.end) == :lt))
      {_actors, tickets, _findings} = Dataset.reduce(records)
      contexts = Map.new(Enum.filter(records, &(&1.kind == "run_context")), &{&1.boot_id, &1.attributes})
      by_ticket = records |> Enum.filter(&(&1.kind == "lifecycle")) |> Enum.group_by(& &1.attributes["ticket"])
      tickets = Map.new(tickets, fn {id, ticket} -> {id, ticket_record(ticket, Map.get(by_ticket, id, []), contexts)} end)
      capacity = datasets |> Enum.flat_map(&(get_in(&1, [:actors, "_daemon", :samples]) || [])) |> Enum.uniq_by(& &1.record_id) |> capacity(window)

      {:ok,
       %{
         tickets: tickets,
         capacity: capacity,
         facts: facts(records, capacity),
         earliest_at: dataset.records |> Enum.map(& &1.timestamp) |> Enum.min(DateTime, fn -> nil end),
         partial?: unreadable? or match?({:error, _}, live) or dataset.warnings != [],
         accounting: if(Map.get(ctx, :include_accounting, false), do: accounting(tickets, window, ctx), else: {:error, :accounting_absent})
       }}
    end
  end

  defp prior_datasets(boot, window, ctx) do
    case Map.fetch(ctx, :prior_loader) do
      {:ok, loader} -> loader.(boot)
      :error -> load_prior(boot, window, ctx)
    end
  end

  # Keep earlier boots: first dispatch and prerequisite merges can precede the window.
  defp load_prior(current, window, ctx) do
    path = Map.get(ctx, :summary_path, &Summaries.run_summary_path/1)
    reader = Map.get(ctx, :summary_reader, &Summaries.load_dataset/1)

    Map.get(ctx, :summary_boot_ids, &Summaries.summary_boot_ids/0).()
    |> Enum.reject(&(&1 == current))
    |> Enum.filter(&BootWindow.before_end?(path.(&1), &1, window.end))
    |> Enum.reduce({[], false}, fn boot, {datasets, unreadable?} ->
      case reader.(boot) do
        {:ok, dataset} -> {[dataset | datasets], unreadable?}
        {:error, _reason} -> {datasets, true}
      end
    end)
  end

  defp ticket_record(ticket, raw, contexts) do
    dispatch = Enum.find(ticket.events, &(&1.event == "dispatch"))
    context = if dispatch, do: Map.get(contexts, dispatch.boot_id, %{}), else: %{}
    attrs = if dispatch, do: cohort(dispatch, context), else: %{}

    Map.merge(ticket, %{
      at: if(dispatch, do: dispatch.timestamp_dt),
      attrs: attrs,
      blockers: if(dispatch, do: dispatch.blockers),
      pr_source?: Enum.any?(raw, &true_pr_open?/1),
      pr_opened_at: raw |> Enum.filter(&true_pr_open?/1) |> Enum.map(& &1.timestamp) |> Enum.min(DateTime, fn -> nil end),
      reviews: raw |> Enum.filter(&review?/1) |> Enum.map(& &1.timestamp)
    })
  end

  defp cohort(dispatch, context) do
    attrs = dispatch |> Map.take([:backend, :model, :effort, :feature, :epic, :start_mode]) |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)

    Map.merge(attrs, %{
      "complexity" => dispatch.complexity,
      "aiur_version" => context["aiur_vsn"],
      "config_hash" => context["config_hash"],
      "tags" => context["capture_tags"] || %{},
      "feature_tags" => if(dispatch.feature, do: [dispatch.feature])
    })
  end

  defp true_pr_open?(record), do: record.attributes["event"] == "pr_opened" and is_binary(record.attributes["source_timestamp"]) and record.attributes["source"] in ["github", "github_reconciliation"]
  defp review?(record), do: record.attributes["event"] == "comment_received" and record.attributes["author_trusted"] == true and not is_nil(record.attributes["review_thread_id"])

  defp facts(records, capacity) do
    base =
      Enum.flat_map(records, fn record ->
        attrs = record.attributes

        []
        |> maybe_fact(true_pr_open?(record), "pr_opened_source_time")
        |> maybe_fact(review?(record), "review_source")
        |> maybe_fact(attrs["event"] == "dispatch" and is_list(attrs["blockers"]), "blocked_by")
        |> maybe_fact(attrs["event"] == "dispatch" and not is_nil(attrs["epic"]), "epic")
      end)

    base |> maybe_fact(capacity != [], "fleet_activity") |> maybe_fact(Enum.any?(capacity, &is_number(&1.cap)), "fleet_capacity") |> Enum.uniq()
  end

  defp maybe_fact(facts, true, fact), do: [fact | facts]
  defp maybe_fact(facts, false, _fact), do: facts

  # Samples hold for at most one sampling interval; gaps and downtime never become idle or active hours.
  defp capacity(samples, window) do
    samples
    |> Enum.group_by(& &1.boot_id)
    |> Enum.flat_map(fn {_boot, samples} ->
      samples
      |> Enum.sort_by(& &1.timestamp_ms)
      |> Enum.chunk_every(2, 1)
      |> Enum.flat_map(&capacity_sample(&1, window))
    end)
    |> Enum.sort_by(& &1.start, DateTime)
  end

  defp capacity_sample([sample | next], window) do
    at = Common.timestamp(sample.timestamp)
    finish = min_at(if(next == [], do: window.end, else: Common.timestamp(hd(next).timestamp)), DateTime.add(at, 5, :second))
    start = max_at(at, window.start)
    finish = min_at(finish, window.end)
    running = sample["fleet_agents_occupied"]
    cap = sample["fleet_agents_configured"]
    valid = sample.fleet_capacity_status == "current" and is_number(running) and running >= 0
    if valid and DateTime.compare(start, finish) == :lt, do: [%{start: start, end: finish, running: running, cap: cap}], else: []
  end

  defp min_at(a, b), do: if(DateTime.compare(a, b) == :gt, do: b, else: a)
  defp max_at(a, b), do: if(DateTime.compare(a, b) == :lt, do: b, else: a)

  defp accounting(tickets, window, ctx) do
    if Map.get(ctx, :accounting_available, Map.has_key?(ctx, :usage_query) or not is_nil(Process.whereis(Aiur.UsageAggregate.Store))) do
      ids =
        tickets
        |> Map.values()
        |> Enum.filter(&(&1.at && Common.in_window?(&1.at, window) && Enum.any?(&1.events, fn e -> e.event == "pr_merged" end)))
        |> Enum.map(& &1.ticket)

      case Map.get(ctx, :identity_lookup, &Aiur.Tracker.fetch_issue_states_by_ids/1).(ids) do
        {:ok, issues} ->
          query = Map.get(ctx, :usage_query, &Aiur.UsageAggregate.query/1)
          snapshot = Map.get(ctx, :usage_snapshot, &Aiur.UsageAggregate.cells_snapshot/0).()
          {:ok, catalog} = RelationshipRegistry.register(Catalog.relationship_catalog(), Relationship.definition())
          by_ticket = Enum.group_by(snapshot.cells, fn {{dims, _measure}, _value} -> dims.ticket end)
          identities = issues |> Enum.map(& &1.tracker_identity) |> Enum.filter(&Aiur.TrackerIdentity.joinable?/1)
          result = query.(%{tickets: identities})
          {:ok, Map.new(issues, fn issue -> {issue.identifier, usage(issue.tracker_identity, result, snapshot, catalog, by_ticket)} end)}

        {:error, reason} ->
          {:error, {:accounting_identity_unavailable, reason}}
      end
    else
      {:error, :accounting_absent}
    end
  catch
    :exit, reason -> {:error, {:accounting_unavailable, reason}}
  end

  defp usage(identity, result, snapshot, catalog, by_ticket) do
    key = Aiur.TrackerIdentity.github_key(identity)
    totals = get_in(result, [:groups, :by_ticket, key])

    complete? =
      result.health == :healthy and result.freshness.status == :fresh and result.aggregate_generation == snapshot.metadata.generation and
        get_in(result, [:coverage, :projection, :partial_records]) == 0 and is_map(totals)

    cond do
      is_nil(key) -> {:error, :accounting_identity_missing}
      not complete? -> {:error, :accounting_incomplete}
      true -> {:ok, Map.put(totals, :token_total, Tokens.total(Map.get(by_ticket, key, []), catalog))}
    end
  end
end
