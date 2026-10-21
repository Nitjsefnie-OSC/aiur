defmodule Aiur.DecisionAttention.Correlation do
  @moduledoc false

  @spec decision_id(term()) :: String.t() | nil
  def decision_id(%{decision: %{decision_id: id}}) when is_binary(id), do: id
  def decision_id(%{decision: %{"decision_id" => id}}) when is_binary(id), do: id
  def decision_id(_result), do: nil

  @spec alert_reason(map()) :: String.t()
  def alert_reason(%{decision_id: id, question: question}) when is_binary(id),
    do: "Executor decision required (Decision #{id}): #{question}"

  def alert_reason(%{question: question}), do: "Decision attention: #{question}"
end
