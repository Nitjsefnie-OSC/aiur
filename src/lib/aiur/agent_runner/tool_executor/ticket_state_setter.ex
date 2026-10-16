defmodule Aiur.AgentRunner.ToolExecutor.TicketStateSetter do
  @moduledoc false

  alias Aiur.AgentRunner.{CiWaitTransition, ReworkHandoffGuard}
  alias Aiur.GitHub.Client, as: GitHubClient

  @spec write(
          Aiur.Issue.t(),
          term(),
          term(),
          map()
        ) :: term()
  def write(issue, state, findings, context) do
    %{
      coordination: coordination,
      workspace: workspace,
      worker_host: worker_host,
      opts: opts,
      coordination_key: coordination_key,
      operation_opts: operation_opts
    } = context

    case tracker_issue_id(issue) do
      issue_id when is_binary(issue_id) ->
        coordination.run.(
          coordination_key.(issue),
          fn ->
            execute_transition(
              issue,
              issue_id,
              state,
              findings,
              coordination,
              workspace,
              worker_host,
              opts
            )
          end,
          operation_opts.(issue)
        )

      nil ->
        {:error, :no_issue_number}
    end
  end

  defp execute_transition(
         issue,
         issue_id,
         state,
         findings,
         coordination,
         workspace,
         worker_host,
         opts
       ) do
    if state in ["ci-wait", "human-review"] do
      handoff(issue, issue_id, state, findings, coordination, workspace, worker_host, opts)
    else
      CiWaitTransition.write(coordination, issue_id, state)
    end
  end

  defp handoff(issue, issue_id, state, findings, coordination, workspace, worker_host, opts) do
    handoff_opts = handoff_options(opts, findings)

    case ReworkHandoffGuard.handoff_blockers(issue, state, workspace, worker_host, handoff_opts) do
      :allow -> CiWaitTransition.write(coordination, issue_id, state)
      {:blocked, reasons} -> {:error, {:rework_handoff_blocked, Enum.join(reasons, "; ")}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handoff_options(opts, findings) do
    opts
    |> Keyword.put(:rework_checklist, findings)
    |> Keyword.put_new(:open_pr_fetcher, &Aiur.CodeHost.fetch_open_pull_request_for_branch/1)
    |> Keyword.put_new(:review_checklist_fetcher, &fetch_review_findings/1)
    |> Keyword.put_new(:pull_request_status_fetcher, &fetch_pull_request_status/1)
  end

  defp fetch_review_findings(identifier) do
    with {:ok, pr} <- Aiur.CodeHost.fetch_open_pull_request_for_branch(identifier),
         number when is_integer(number) <- pr["number"] do
      Aiur.CodeHost.fetch_unaddressed_pr_review_thread_comments(number)
    else
      _ -> {:error, :review_findings_unavailable}
    end
  end

  defp fetch_pull_request_status(pr) do
    case GitHubClient.fetch_open_pull_request(pr["number"]) do
      {:ok, %{"isDraft" => draft, "mergeable" => mergeable}} ->
        {:ok, %{draft?: draft, mergeable: mergeable}}

      other ->
        other
    end
  end

  defp tracker_issue_id(issue) do
    case Map.get(issue, :id) || Map.get(issue, :identifier) do
      id when is_binary(id) and id != "" -> id
      id when is_integer(id) -> Integer.to_string(id)
      _ -> nil
    end
  end
end
