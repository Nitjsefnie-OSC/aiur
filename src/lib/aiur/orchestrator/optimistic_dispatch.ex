defmodule Aiur.Orchestrator.OptimisticDispatch do
  @moduledoc false
  require Logger
  alias Aiur.BuildQueue.Hints
  alias Aiur.Orchestrator.OptimisticLedger
  alias Aiur.RunTelemetry.Lifecycle
  alias Aiur.StartTrigger.ProgressStore

  @spec record(Aiur.Issue.t(), String.t(), [String.t()]) :: :ok
  def record(_issue, _attempt_id, []), do: :ok

  def record(issue, attempt_id, ids) do
    blockers =
      Enum.map(ids, fn id ->
        facts = ProgressStore.lookup(id) || %{}

        %{
          "id" => id,
          "pr_number" => facts[:pr_number],
          "pr_head_sha_at_start" => facts[:head_sha],
          "last_head_sha" => facts[:head_sha],
          "pr_state" => pr_state(facts),
          "failed_cause" => nil,
          "failed_at_ms" => nil,
          "merged_at_ms" => nil
        }
      end)

    trigger = Hints.trigger_for(issue.id)
    attrs = %{attempt_id: attempt_id, start_trigger: trigger, started_at_ms: System.system_time(:millisecond), blockers: blockers}

    case OptimisticLedger.record_start(issue.identifier, attrs) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Optimistic start not persisted ticket=#{issue.identifier} attempt=#{attempt_id} reason=#{inspect(reason)}")
    end

    Lifecycle.record(issue.identifier, attempt_id, :optimistic_start, :point, %{
      start_trigger: trigger,
      blockers: ids,
      blocker_prs: Enum.map(blockers, & &1["pr_number"])
    })

    :ok
  end

  defp pr_state(%{stage: :pr_merged}), do: "merged"
  defp pr_state(%{closed_unmerged?: true}), do: "closed"
  defp pr_state(%{stage: stage}) when stage in [:pr_opened, :pr_ci_green, :pr_approved], do: "open"
  defp pr_state(_), do: nil
end
