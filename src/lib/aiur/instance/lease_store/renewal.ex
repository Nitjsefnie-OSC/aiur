defmodule Aiur.Instance.LeaseStore.Renewal do
  @moduledoc false
  require Logger

  alias Aiur.Instance.LeaseStore

  @spec start(pid(), term(), pos_integer(), pos_integer(), pos_integer(), GenServer.server(), keyword()) :: :ok
  def start(parent, key, interval, ttl_ms, margin_ms, server, opts) do
    monitor = Process.monitor(parent)
    now_fun = Keyword.get(opts, :monotonic_now, fn -> System.monotonic_time(:millisecond) end)

    renew_fun =
      Keyword.get(opts, :renew_fun, fn current_key, current_server, ttl ->
        LeaseStore.renew(current_key, server: current_server, ttl_ms: ttl)
      end)

    renew_loop(%{
      parent: parent,
      monitor: monitor,
      key: key,
      interval: interval,
      ttl_ms: ttl_ms,
      margin_ms: margin_ms,
      server: server,
      renew_fun: renew_fun,
      now_fun: now_fun,
      last_good_ms: now_fun.()
    })
  end

  defp renew_loop(%{parent: parent, monitor: monitor, interval: interval} = renewal) do
    receive do
      {:DOWN, ^monitor, :process, ^parent, _reason} -> :ok
    after
      interval -> renew_once(renewal)
    end
  end

  defp renew_once(%{key: key, server: server, ttl_ms: ttl, renew_fun: renew_fun} = renewal) do
    case renew_fun.(key, server, ttl) do
      :ok ->
        renew_loop(%{renewal | last_good_ms: renewal.now_fun.()})

      {:error, :lease_lost} ->
        Process.exit(renewal.parent, {:shared_ticket_lease_lost, key})

      {:error, reason} ->
        retry_or_fence(renewal, reason)
    end
  end

  defp retry_or_fence(renewal, reason) do
    deadline = renewal.last_good_ms + renewal.ttl_ms - renewal.margin_ms
    remaining_ms = deadline - renewal.now_fun.()

    if remaining_ms <= 0 do
      Logger.error("ticket lease renewal deadline missed key=#{renewal.key}: #{inspect(reason)}; stopping worker")
      Process.exit(renewal.parent, {:shared_ticket_lease_lost, renewal.key})
    else
      Logger.warning("ticket lease renewal unavailable key=#{renewal.key}: #{inspect(reason)}; worker stops in #{remaining_ms}ms unless renewed")
      Process.sleep(min(renewal.interval, remaining_ms))
      renew_loop(renewal)
    end
  end
end
