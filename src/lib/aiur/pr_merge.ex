defmodule Aiur.PrMerge do
  @moduledoc "Standalone, operator-only squash merge with policy gates."
  alias Aiur.PrMerge.{Client, Facts, Gate, Identity, MergeResult, Record}

  @spec run(map(), keyword()) :: non_neg_integer()
  def run(opts, deps \\ []) do
    puts = Keyword.get(deps, :puts, &IO.puts/1)
    report(execute(opts, deps, puts), puts)
  rescue
    _error ->
      IO.puts(:stderr, "aiur pr merge: unexpected tool failure; merge outcome may be unknown")
      1
  end

  defp execute(opts, deps, puts) do
    with {:ok, settings} <- Keyword.get(deps, :settings, &Aiur.Config.settings_uncached/0).(),
         :ok <- Identity.guard(settings, Keyword.get(deps, :cwd, File.cwd!()), Keyword.get(deps, :agent_bin, System.get_env("AIUR_AGENT_BIN"))),
         {:ok, token} <- Keyword.get(deps, :token, &Identity.token/0).(),
         api <- Keyword.get(deps, :api, &Client.request(token, &1, &2, &3)),
         {:ok, user} <- api.("get", "user", nil),
         :ok <- Identity.allowed(user, settings.tracker.github),
         :ok <- main_note(settings, deps, puts),
         {:ok, pr} <- Facts.read(api, settings, opts.number, user),
         :ok <- gate(pr, settings, opts),
         :ok <- merge_result(pr, settings, token, deps, puts),
         {:ok, fresh} <- Facts.read(api, settings, opts.number, user),
         :ok <- gate(fresh, settings, opts),
         true <- fresh.base_sha == pr.base_sha or {:refuse, ["base moved during premerge checks; rerun"]} do
      finish(api, fresh, settings, opts, deps, puts, user)
    end
  end

  defp main_note(settings, deps, puts) do
    if settings.merge_policy.main_watch.enabled do
      case Keyword.get(deps, :watcher_state, &Record.watcher_state/0).() do
        %{"status" => "red", "red_since" => since} = state -> puts.("NOTE integration branch is red since #{since} (fixer #{state["fixer_identifier"] || "unavailable"})")
        _ -> :ok
      end
    end

    :ok
  end

  defp gate(pr, settings, opts) do
    case Gate.refusals(pr, settings.merge_policy, opts) do
      [] -> :ok
      reasons -> {:refuse, reasons}
    end
  end

  defp merge_result(pr, settings, token, deps, puts) do
    repo = settings.tracker.github.repo
    encoded = Base.encode64("x-access-token:" <> token)
    env = [{"GIT_CONFIG_COUNT", "1"}, {"GIT_CONFIG_KEY_0", "http.https://github.com/.extraheader"}, {"GIT_CONFIG_VALUE_0", "AUTHORIZATION: basic " <> encoded}, {"GIT_TERMINAL_PROMPT", "0"}]
    options = [repo: Path.expand("~/.aiur/repo/#{repo}/pr-merge.git"), remote: "https://github.com/#{repo}.git", env: env, puts: puts]
    Keyword.get(deps, :merge_result, &MergeResult.check/3).(pr, settings, options)
  end

  defp finish(_api, pr, settings, %{dry_run: true}, _deps, puts, _user) do
    puts.("DRY RUN policy ci=#{settings.merge_policy.ci}; pending=#{Enum.join(Gate.pending(pr), ",")}; nothing merged")
    :ok
  end

  defp finish(api, pr, settings, opts, deps, puts, user) do
    root = Keyword.get(deps, :log_root, Path.expand("~/.aiur/logs/pr-merge"))
    repo = settings.tracker.github.repo

    with :ok <- File.mkdir_p(root),
         :ok <- approve(api, repo, pr, opts.approve_body),
         {:ok, %{"merged" => true, "sha" => sha}} <- api.("put", "repos/#{repo}/pulls/#{pr.number}/merge", merge_body(pr)) do
      record = %{
        repo: repo,
        pr: pr.number,
        sha: pr.head,
        base_sha: pr.base_sha,
        merged_sha: sha,
        pending: Gate.pending(pr),
        pending_count: length(Gate.pending(pr)),
        policy: settings.merge_policy.ci,
        actor: user["login"],
        merged_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      puts.("MERGED ##{pr.number} #{sha}; policy ci=#{record.policy}; pending=#{Enum.join(record.pending, ",")}")
      record(record, root, deps, puts)
      :ok
    else
      {:ok, %{"message" => message}} -> {:error, message}
      {:error, _} = error -> error
      _ -> {:error, "GitHub did not confirm a merge"}
    end
  end

  defp approve(_api, _repo, _pr, nil), do: :ok

  defp approve(api, repo, pr, body) do
    case api.("post", "repos/#{repo}/pulls/#{pr.number}/reviews", %{event: "APPROVE", body: body, commit_id: pr.head}) do
      {:ok, %{"state" => "APPROVED", "commit_id" => head}} when head == pr.head -> :ok
      {:error, _} = error -> error
      _ -> {:error, "GitHub did not confirm approval at the reviewed head"}
    end
  end

  defp merge_body(pr), do: %{merge_method: "squash", sha: pr.head, commit_title: "#{pr.title} (##{pr.number})", commit_message: ""}

  defp record(record, root, deps, puts) do
    if Record.append(record, root) != :ok, do: puts.("WARNING merged, but merge ledger write failed")
    if Keyword.get(deps, :notify, &Record.notify/1).(record) != :ok, do: puts.("WARNING merged, but daemon event delivery failed")
  end

  defp report(:ok, _puts), do: 0

  defp report({:refuse, reasons}, puts) do
    Enum.each(reasons, &puts.("REFUSE " <> &1))
    2
  end

  defp report({:error, reason}, puts) do
    puts.("ERROR " <> inspect(reason))
    1
  end
end
