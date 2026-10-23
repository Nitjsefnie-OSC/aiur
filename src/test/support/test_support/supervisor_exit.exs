defmodule Aiur.TestSupport.SupervisorExit do
  @moduledoc false

  @reason_key {__MODULE__, :reason}
  @monitor_key {__MODULE__, :monitor}
  @pid_key {__MODULE__, :pid}

  def start_monitoring do
    :persistent_term.put(@reason_key, nil)
    monitor(Process.whereis(Aiur.Supervisor))
  end

  def exit_reason, do: :persistent_term.get(@reason_key)

  def handle_info({:DOWN, ref, :process, {Aiur.Supervisor, _node}, reason}, state) do
    if ref == :persistent_term.get(@monitor_key) do
      :persistent_term.put(@reason_key, reason)
      Process.send_after(self(), :refresh_supervisor_monitor, 250)
    end

    {:noreply, state}
  end

  def handle_info(:refresh_supervisor_monitor, state) do
    case Process.whereis(Aiur.Supervisor) do
      pid when is_pid(pid) ->
        if pid != :persistent_term.get(@pid_key) do
          monitor(pid)
          :persistent_term.put(@reason_key, nil)
        end

      _ ->
        Process.send_after(self(), :refresh_supervisor_monitor, 250)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp monitor(pid) when is_pid(pid) do
    :persistent_term.put(@pid_key, pid)
    :persistent_term.put(@monitor_key, Process.monitor(pid))
  end

  defp monitor(nil) do
    :persistent_term.put(@pid_key, nil)
    :persistent_term.put(@monitor_key, Process.monitor(Aiur.Supervisor))
  end
end
