defmodule Aiur.Orchestrator.CommentReworkRetry do
  @moduledoc false

  @spec limit_reached?(pos_integer(), term(), pos_integer()) :: boolean()
  def limit_reached?(attempt, reason, max_attempts) do
    not broker_timeout?(reason) and attempt >= max_attempts
  end

  @spec attempt_label(pos_integer(), term(), pos_integer()) :: String.t()
  def attempt_label(attempt, reason, max_attempts) do
    limit = if broker_timeout?(reason), do: "until success", else: "#{max_attempts}"
    "#{attempt}/#{limit}"
  end

  defp broker_timeout?(:github_budget_broker_timeout), do: true
  defp broker_timeout?({:github, :local_hold, %{reason: :github_budget_broker_timeout}}), do: true
  defp broker_timeout?({:github, :timeout, %{reason: :github_budget_broker_timeout}}), do: true
  defp broker_timeout?(_reason), do: false
end
