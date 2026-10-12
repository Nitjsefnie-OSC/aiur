defmodule Aiur.MainWatch.Fixer do
  @moduledoc "Files and reconciles main-fix tickets from the main-watch background task."
  alias Aiur.GitHub.{Config, MainFixer, ResourceStore, StatePolicy}
  alias Aiur.MainWatch.{FixerGitHub, FixerWatchdog}

  @spec reconcile([map()], map(), keyword()) :: :ok | {:error, term()}
  def reconcile(observations, watch, opts \\ [])

  def reconcile(observations, %{on_red: "dispatch_fixer"} = watch, opts) when observations != [] do
    observation = List.last(observations)

    with {:ok, issues} <- call(opts, :fixer_open, [watch.fixer_label, opts], &FixerGitHub.open/2),
         issues = Enum.filter(issues, &(not is_nil(MainFixer.marker(&1["body"])))),
         :ok <- act(observation, issues, watch, opts) do
      FixerWatchdog.check(issues, opts)
    else
      {:error, reason} = error ->
        alert("system.main.fixer.failed", %{reason: inspect(reason)}, opts)
        error
    end
  end

  def reconcile(_observations, _watch, _opts), do: :ok

  defp act(observation, issues, watch, opts) do
    cond do
      Enum.all?(observation.checks, &(&1.conclusion in ~w(success neutral skipped))) ->
        recover(issues, observation.sha, opts)

      observation.digest.flake_only and observation.digest.tests != :unknown and not observation.digest.truncated ->
        :ok

      true ->
        file(observation, issues, watch, opts)
    end
  end

  defp file(observation, issues, watch, opts) do
    signature = signature(observation)
    matching = Enum.find(issues, fn issue -> String.contains?(issue["body"], "signature=#{signature}") or overlap?(issue["body"], observation.digest.tests) end)
    body = body(observation, signature)

    case matching do
      nil ->
        create(observation, body, watch, opts)

      issue ->
        comment_run(issue, observation, body, opts)
    end
  end

  defp comment_run(issue, observation, body, opts) do
    id = to_string(issue["number"])

    if String.contains?(issue["body"], "signature=#{signature(observation)} sha=#{observation.sha}") and
         Enum.all?(observation.run_urls, &String.contains?(issue["body"], &1)) and observation.run_urls != [],
       do: :ok,
       else: once("run:#{id}:#{hash({signature(observation), observation.sha, observation.run_urls})}", opts, fn -> call(opts, :fixer_comment, [id, body, opts], &FixerGitHub.comment/3) end)
  end

  defp create(observation, body, watch, opts) do
    app? = Keyword.get_lazy(opts, :fixer_app?, &MainFixer.app_mode?/0)
    state_label = if app?, do: StatePolicy.state_label(Config.label_prefix(), "todo"), else: "needs-triage"
    issue = %{"title" => "Main red at #{String.slice(observation.sha, 0, 12)}", "body" => body, "labels" => [state_label, "priority:1", "complexity:1", watch.fixer_label]}

    with {:ok, created} <- call(opts, :fixer_create, [issue, opts], &FixerGitHub.create/2) do
      if app?, do: refresh(opts), else: alert("system.main.fixer.needs_triage", %{issue: created["number"], reason: "PAT/shared identity cannot authorize daemon-filed work"}, opts)
      :ok
    end
  end

  defp refresh(opts) do
    case Keyword.get(opts, :fixer_refresh, &Aiur.Orchestrator.request_refresh/0).() do
      status when is_map(status) or status == :ok -> :ok
      reason -> alert("system.main.fixer.dispatch_unavailable", %{reason: inspect(reason)}, opts)
    end
  end

  defp recover(issues, sha, opts) do
    Enum.reduce_while(issues, :ok, fn issue, :ok ->
      id = to_string(issue["number"])
      result = once("recovery:#{id}:#{hash(issue["body"])}", opts, fn -> recovery(id, sha, opts) end)
      if result == :ok, do: {:cont, :ok}, else: {:halt, result}
    end)
  end

  defp recovery(id, sha, opts) do
    with {:ok, open?} <- call(opts, :fixer_pr_open?, [id, opts], &FixerGitHub.pr_open?/2),
         :ok <- call(opts, :fixer_comment, [id, "main is green at #{sha}. This ticket remains open; fixer PRs wait for full CI.", opts], &FixerGitHub.comment/3) do
      if not open?, do: alert("system.main.fixer.no_pr", %{issue: id, sha: sha}, opts)
      :ok
    end
  end

  defp overlap?(body, tests) when is_list(tests), do: not String.contains?(body, "<!-- aiur:main-watch test=") or Enum.any?(tests, &String.contains?(body, test_marker(&1.identity)))
  defp overlap?(_body, _tests), do: true
  defp test_marker(identity), do: "<!-- aiur:main-watch test=#{hash(identity)} -->"
  defp signature(observation), do: observation.digest.signature || hash(observation.checks |> Enum.reject(&(&1.conclusion in ~w(success neutral skipped))) |> Enum.map(& &1.name) |> Enum.sort())
  defp hash(value), do: :crypto.hash(:sha256, :erlang.term_to_binary(value)) |> Base.encode16(case: :lower)

  defp body(observation, signature) do
    tests = observation.digest.tests
    detail = if is_list(tests), do: Enum.map_join(tests, "\n", &"- #{&1.identity} (#{&1.classification}) #{test_marker(&1.identity)}"), else: "Unknown; inspect the failing checks."
    paths = if is_list(tests), do: tests |> Enum.map(&Map.get(&1, :path)) |> Enum.filter(&is_binary/1) |> Enum.uniq(), else: []
    commands = if paths == [], do: "mix test", else: Enum.map_join(paths, "\n", &"mix test #{Aiur.Shell.escape(&1, fast_path: true)}")
    suspects = Enum.map_join(Map.get(observation, :suspect_merges, []), "\n", &inspect/1)

    """
    <!-- aiur:main-watch signature=#{signature} sha=#{observation.sha} -->
    Main CI failed at #{observation.sha}. Last green: #{Map.get(observation, :last_green_sha) || "unknown"}.

    Runs: #{Enum.join(observation.run_urls, "\n")}
    Failing checks: #{inspect(Enum.reject(observation.checks, &(&1.conclusion in ~w(success neutral skipped))))}

    Failing tests:
    #{detail}

    Suspect PRs (early merges marked):
    #{suspects}

    Reproduce locally:
    ```sh
    #{commands}
    ```

    This PR waits for full CI. Diagnose and fix the main failure; do not automatically revert a suspect PR.
    """
  end

  @spec once(String.t(), keyword(), (-> :ok | {:error, term()})) :: :ok | {:error, term()}
  def once(identity, opts, action) do
    key = ResourceStore.key_for_repo(:main_watch, Config.repo(), "fixer:" <> identity)
    read = Keyword.get(opts, :fixer_read, &ResourceStore.fetch/1)
    write = Keyword.get(opts, :fixer_write, fn key -> with :ok <- ResourceStore.put_resource(key, %{"done" => true}, source: :mutation), do: ResourceStore.flush() end)

    case read.(key) do
      {:ok, %{data: %{"done" => true}}} -> :ok
      _ -> with :ok <- action.(), do: write.(key)
    end
  end

  @spec alert(String.t(), map(), keyword()) :: :ok
  def alert(topic, payload, opts) do
    Keyword.get(opts, :fixer_alert, fn topic, payload -> Aiur.Alerts.emit_system(topic, message: "Main fixer: #{inspect(payload)}", durable: true, needs_attention: true, exchange_payload: payload) end).(
      topic,
      payload
    )
  end

  defp call(opts, name, args, default), do: apply(Keyword.get(opts, name, default), args)
end
