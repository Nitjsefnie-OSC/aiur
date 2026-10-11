defmodule Aiur.MainWatch.GitHub do
  @moduledoc "Bounded base-branch Actions observations through the governed GitHub transport."
  alias Aiur.CI.FailureDigest
  alias Aiur.GitHub.{AppCredentials, AppToken, Errors, PullRequests, Transport}

  @spec poll(String.t(), [String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def poll(branch, workflows, opts \\ []) do
    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts),
         {:ok, commits} <- commits(owner, repo, branch, token, opts),
         {:ok, runs} <- runs(owner, repo, branch, commits, workflows, token, opts),
         {:ok, observations} <- observations(commits, runs, workflows, opts) do
      {:ok, %{observations: observations, runs: runs, commits: commits, actions_write: Keyword.get_lazy(opts, :actions_write, fn -> actions_write?(opts) end)}}
    end
  end

  @spec actions_write?(keyword()) :: boolean()
  def actions_write?(opts \\ []) do
    with true <- AppCredentials.configured?(),
         {:ok, key} <- AppCredentials.parse_private_key(),
         jwt = AppToken.app_jwt(key, AppCredentials.app_id()),
         url = "#{Transport.base_url()}/app/installations/#{AppCredentials.installation_id()}",
         request = %{method: :get, url: url, token: jwt, caller: "main_watch_permissions", credential_pinned?: true},
         {:ok, %{status: 200, body: installation}} when is_map(installation) <- request_fun(opts).(request) do
      permissions = installation["permissions"]
      is_map(permissions) and permissions["actions"] == "write"
    else
      _ -> false
    end
  end

  @spec rerun(pos_integer(), keyword()) :: :ok | {:error, term()}
  def rerun(id, opts \\ [])

  def rerun(id, opts) when is_integer(id) and id > 0 do
    with {:ok, {owner, repo}} <- Transport.parse_repo(),
         {:ok, token} <- Transport.require_token(opts) do
      request = %{method: :post, url: "#{Transport.base_url()}/repos/#{owner}/#{repo}/actions/runs/#{id}/rerun", token: token, body: %{}, caller: "main_watch_canary"}

      case request_fun(opts).(request) do
        {:ok, %{status: 201}} -> :ok
        {:ok, response} -> {:error, Errors.github_status_error(response)}
        {:error, reason} -> {:error, Errors.classify_error({:error, reason})}
      end
    end
  end

  def rerun(_, _), do: {:error, :invalid_actions_run_id}

  defp commits(owner, repo, branch, token, opts) do
    url = "#{Transport.base_url()}/repos/#{owner}/#{repo}/commits?" <> URI.encode_query(%{sha: branch, per_page: 20})

    case request_fun(opts).(%{method: :get, url: url, token: token, caller: "main_watch_commits"}) do
      {:ok, %{status: 200, body: commits}} when is_list(commits) ->
        if Enum.all?(commits, &(is_map(&1) and is_binary(&1["sha"]))), do: {:ok, commits |> Enum.take(20) |> Enum.map(& &1["sha"])}, else: {:error, :invalid_main_commits}

      {:ok, response} ->
        {:error, Errors.github_status_error(response)}

      {:error, reason} ->
        {:error, Errors.classify_error({:error, reason})}
    end
  end

  defp runs(owner, repo, branch, commits, workflows, token, opts) do
    Enum.reduce_while(commits, {:ok, []}, fn sha, {:ok, acc} ->
      url = "#{Transport.base_url()}/repos/#{owner}/#{repo}/actions/runs?" <> URI.encode_query(%{branch: branch, head_sha: sha, event: "push", per_page: 100})

      case runs_page(url, token, opts) do
        {:ok, runs} -> {:cont, {:ok, acc ++ Enum.filter(runs, &watched?(&1, sha, branch, workflows))}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, runs} -> {:ok, runs |> Enum.map(&normalize/1) |> Enum.sort_by(& &1.id, :desc)}
      error -> error
    end
  end

  defp runs_page(url, token, opts) do
    case request_fun(opts).(%{method: :get, url: url, token: token, caller: "main_watch_runs"}) do
      {:ok, %{status: 200, body: %{"workflow_runs" => runs}} = response} when is_list(runs) ->
        if Transport.parse_next_page_url(Map.get(response, :headers, [])), do: {:error, :main_runs_incomplete}, else: {:ok, runs}

      {:ok, %{status: 200}} ->
        {:error, :invalid_main_runs}

      {:ok, response} ->
        {:error, Errors.github_status_error(response)}

      {:error, reason} ->
        {:error, Errors.classify_error({:error, reason})}
    end
  end

  defp watched?(run, sha, branch, workflows),
    do: run["head_sha"] == sha and run["head_branch"] == branch and run["event"] == "push" and (workflows == [] or run["name"] in workflows)

  defp normalize(run),
    do: %{
      id: run["id"],
      sha: run["head_sha"],
      name: run["name"],
      suite_id: run["check_suite_id"],
      status: run["status"],
      conclusion: run["conclusion"],
      attempt: run["run_attempt"] || 1,
      completed_at: timestamp(run["updated_at"]),
      url: run["html_url"]
    }

  defp observations(commits, runs, workflows, opts) do
    commits
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, []}, &append_observation(&1, &2, runs, workflows, opts))
  end

  defp append_observation(sha, {:ok, acc}, runs, workflows, opts) do
    latest = runs |> Enum.filter(&(&1.sha == sha)) |> Enum.uniq_by(& &1.name)

    if complete_workflows?(latest, workflows) and Enum.all?(latest, &(&1.status == "completed" and &1.conclusion not in [nil, "cancelled"])) do
      case observation(sha, latest, opts) do
        {:ok, observation} -> {:cont, {:ok, acc ++ [observation]}}
        error -> {:halt, error}
      end
    else
      {:cont, {:ok, acc}}
    end
  end

  defp complete_workflows?([], _), do: false
  defp complete_workflows?(runs, workflows), do: Enum.all?(workflows, fn name -> Enum.any?(runs, &(&1.name == name)) end)

  defp observation(sha, runs, opts) do
    suites = Enum.map(runs, & &1.suite_id)

    with true <- Enum.all?(suites, &is_integer/1) and Enum.all?(runs, &is_integer(&1.completed_at)),
         {:ok, ci} <- PullRequests.fetch_commit_ci_status(sha, opts),
         checks = latest_checks(ci.check_runs, suites),
         ci = %{ci | check_runs: checks},
         true <- checks != [] and Enum.all?(checks, &(&1["status"] == "completed")),
         {:ok, digest} <- FailureDigest.build_from_ci(sha, ci, Keyword.put(opts, :check_suite_ids, suites)) do
      {:ok,
       %{
         sha: sha,
         completed_at: runs |> Enum.map(& &1.completed_at) |> Enum.max(),
         checks: Enum.map(checks, &%{name: &1["name"], conclusion: &1["conclusion"]}),
         digest: digest,
         failed_workflow: Enum.any?(runs, &(&1.conclusion == "failure")),
         run_urls: Enum.map(runs, & &1.url),
         suspect_merges: []
       }}
    else
      false -> {:error, :incomplete_main_checks}
      error -> error
    end
  end

  defp latest_checks(checks, suites) do
    checks
    |> Enum.filter(&(get_in(&1, ["check_suite", "id"]) in suites and get_in(&1, ["app", "slug"]) == "github-actions"))
    |> Enum.sort_by(& &1["id"], :desc)
    |> Enum.uniq_by(&{get_in(&1, ["check_suite", "id"]), &1["name"]})
  end

  defp timestamp(value) do
    case value && DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> DateTime.to_unix(datetime, :millisecond)
      _ -> nil
    end
  end

  defp request_fun(opts), do: Keyword.get(opts, :request_fun, &Transport.default_request_fun/1)
end
