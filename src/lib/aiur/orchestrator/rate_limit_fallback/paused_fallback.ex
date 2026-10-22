defmodule Aiur.Orchestrator.RateLimitFallback.PausedFallback do
  @moduledoc false

  alias Aiur.{CodingAgent, Issue, ModelAvailability}
  alias Aiur.Orchestrator.State

  @wait_seconds 600

  @spec backend(Issue.t(), String.t(), String.t() | nil, keyword()) :: String.t() | nil
  def backend(issue, current_backend, configured_fallback, opts) do
    route = Keyword.get_lazy(opts, :routing_backend, fn -> CodingAgent.routing_backend(issue) end)
    if is_binary(route) and route != current_backend, do: route, else: configured_fallback
  end

  @spec eligible?(map(), Issue.t(), String.t(), String.t() | nil, String.t(), keyword()) :: boolean()
  def eligible?(entry, issue, current_backend, fallback_backend, primary_backend, opts) do
    State.paused_running_entry?(entry) and
      Map.get(entry, :paused_reason) == :usage_limit_exhausted and
      wait_elapsed?(entry, opts) and
      fallback_target_usable?(fallback_backend, current_backend, issue, opts) and
      route_allows_fallback?(issue, current_backend, primary_backend, opts)
  end

  defp fallback_target_usable?(backend, current_backend, issue, opts) do
    is_binary(backend) and backend in CodingAgent.known_backends() and backend != current_backend and
      ModelAvailability.available?(backend, opts) and is_nil(CodingAgent.override_backend(issue))
  end

  defp route_allows_fallback?(issue, current_backend, primary_backend, opts) do
    current_backend == primary_backend or routing_fallback?(issue, current_backend, opts)
  end

  defp routing_fallback?(issue, current_backend, opts) do
    route = Keyword.get_lazy(opts, :routing_backend, fn -> CodingAgent.routing_backend(issue) end)
    is_binary(route) and route != current_backend
  end

  defp wait_elapsed?(entry, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    wait_seconds = Keyword.get(opts, :paused_fallback_wait_seconds, @wait_seconds)

    case Map.get(entry, :paused_at) do
      %DateTime{} = paused_at -> DateTime.diff(now, paused_at, :second) >= wait_seconds
      _ -> true
    end
  end
end
