defmodule Aiur.DecisionAttentionResolution do
  @moduledoc false

  alias Aiur.DecisionStore
  alias Aiur.Orchestrator
  alias Aiur.Orchestrator.StatusReport

  @spec resolve?(map(), map()) :: boolean()
  def resolve?(attention, state) do
    stale_condition?(attention, state) or answered_operator_decision?(attention, state) or stranded_owner?(attention, state)
  end

  @spec live_owner?(String.t()) :: boolean()
  def live_owner?(identifier), do: StatusReport.has_live_owner_api(Orchestrator, identifier, 1_000)

  defp stranded_owner?(%{slug: "stranded-requeued", issue: %{identifier: identifier}}, %{owner_lookup: lookup})
       when is_function(lookup, 1),
       do: lookup.(identifier) == true

  defp stranded_owner?(_attention, _state), do: false

  defp stale_condition?(%{slug: slug, opened_at: %DateTime{} = opened_at}, state) do
    condition_attention?(slug) and
      DateTime.diff(state.now_fun.(), opened_at, :millisecond) >= state.condition_attention_ttl_ms
  end

  defp stale_condition?(_attention, _state), do: false

  defp answered_operator_decision?(%{slug: "operator-decision", issue: %{identifier: identifier}}, state) do
    state.decision_store
    |> DecisionStore.list()
    |> Enum.all?(fn decision ->
      decision.ticket.identifier != identifier or decision.decision_status not in [:open, :deferred]
    end)
  end

  defp answered_operator_decision?(_attention, _state), do: false

  defp condition_attention?(slug) do
    base_branch = Aiur.Config.base_branch()
    branch_red = "#{base_branch}-red"
    branch_ci_red = "#{base_branch}-ci-red"
    detailed_ci_red_prefix = branch_ci_red <> "-"

    slug in [branch_red, branch_ci_red] or
      (String.starts_with?(slug, detailed_ci_red_prefix) and
         byte_size(slug) > byte_size(detailed_ci_red_prefix))
  end
end
