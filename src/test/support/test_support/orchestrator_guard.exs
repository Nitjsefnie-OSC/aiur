defmodule Aiur.TestSupport.OrchestratorGuard do
  @moduledoc """
  Names the test that leaves the shared `Aiur.Orchestrator` down (#4909).

  It is also an ExUnit formatter that remembers the last finished test of any
  case template, so the shared setup can say who ran before it had to restart
  the orchestrator. The shared teardown fails a sync test that ends with the
  orchestrator down, so the leaking test fails itself instead of its
  successors. "Down" also covers a stand-in left holding the name while the
  supervised child is unnamed. A plain `ExUnit.Case` leak is recorded when the
  next sync `Aiur.TestSupport` setup has to restore it, or when the suite ends
  with it broken, and `verify_suite!/0` then fails the run.

  Leaks are never judged inside the formatter: its events are casts that land
  after later tests have started, so what it would see belongs to them.
  """
  use GenServer

  alias Aiur.TestSupport.OrchestratorChild

  alias Aiur.TestSupport.RuntimeChildren

  # persistent_term, not GenServer state: after_suite callbacks run once formatters have stopped.
  @suite_leaks_key {__MODULE__, :suite_leaks}
  @instance_key_key {__MODULE__, :instance_key}
  @app_env_key {__MODULE__, :app_env}
  @last_finished_key {__MODULE__, :last_finished}
  @guarded_app_env_keys [:decision_state_dir, :github_budget_dir, :executor_state_dir, :runtime_state_dir]

  @impl true
  def init(_opts) do
    Process.register(self(), __MODULE__)
    :persistent_term.put(@suite_leaks_key, [])
    :persistent_term.put(@instance_key_key, System.get_env("AIUR_INSTANCE_KEY"))
    :persistent_term.put(@app_env_key, capture_app_env())
    :persistent_term.put(@last_finished_key, nil)
    {:ok, nil}
  end

  @impl true
  def handle_cast({:test_finished, %ExUnit.Test{state: {tag, _}}}, last) when tag in [:excluded, :skipped, :invalid],
    do: {:noreply, last}

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, _last) do
    name = "#{inspect(test.module)}: #{test.name}"
    :persistent_term.put(@last_finished_key, name)
    {:noreply, name}
  end

  def handle_cast(_event, last), do: {:noreply, last}

  @impl true
  def handle_call(:last_finished, _from, last), do: {:reply, last, last}

  @doc "Fails the suite when a plain ExUnit case leaked the orchestrator. Runs after the formatters stop."
  @spec verify_suite!() :: :ok
  def verify_suite! do
    if leak = leak(), do: record_leak(:persistent_term.get(@last_finished_key, nil), leak)

    expected_instance_key = :persistent_term.get(@instance_key_key, nil)
    actual_instance_key = System.get_env("AIUR_INSTANCE_KEY")

    app_env_leaks = app_env_leaks()
    instance_key_leak = if actual_instance_key == expected_instance_key, do: [], else: ["AIUR_INSTANCE_KEY changed from #{inspect(expected_instance_key)} to #{inspect(actual_instance_key)}"]
    state_leaks = app_env_leaks ++ instance_key_leak

    if state_leaks != [] do
      last = :persistent_term.get(@last_finished_key, nil) || "unknown"
      raise "test suite left shared state changed after #{last}: #{Enum.join(state_leaks, "; ")}"
    end

    case :persistent_term.get(@suite_leaks_key, []) do
      [] -> :ok
      leaks -> raise "plain ExUnit tests broke Aiur.Orchestrator: #{Enum.join(leaks, ", ")}"
    end
  end

  @doc false
  @spec capture_shared_state() :: %{app_env: %{optional(atom()) => {:ok, term()} | :error}, instance_key: String.t() | nil}
  def capture_shared_state do
    %{app_env: capture_app_env(), instance_key: System.get_env("AIUR_INSTANCE_KEY")}
  end

  @doc false
  @spec verify_restored_shared_state!([{atom(), {:ok, term()} | :error}], String.t() | nil, map()) :: :ok
  def verify_restored_shared_state!(previous_app_env, previous_instance_key, context) do
    expected = %{
      app_env: Map.new(previous_app_env),
      instance_key: previous_instance_key
    }

    verify_restored!(Map.put(context, :aiur_expected_shared_state, expected))
  end

  @doc false
  @spec verify_shared_state_before_test!(map()) :: :ok
  def verify_shared_state_before_test!(context) do
    expected = :persistent_term.get(@app_env_key, capture_app_env())
    expected_instance_key = :persistent_term.get(@instance_key_key, System.get_env("AIUR_INSTANCE_KEY"))
    app_env_leaks = app_env_leaks()
    actual_instance_key = System.get_env("AIUR_INSTANCE_KEY")
    instance_key_leaks = if actual_instance_key == expected_instance_key, do: [], else: ["AIUR_INSTANCE_KEY changed from #{inspect(expected_instance_key)} to #{inspect(actual_instance_key)}"]
    leaks = app_env_leaks ++ instance_key_leaks

    if leaks != [] do
      Enum.each(@guarded_app_env_keys, fn key -> restore_app_env(key, Map.fetch!(expected, key)) end)
      restore_instance_key(expected_instance_key)
      last = last_finished() || "unknown"
      raise "#{test_name(context)} started after #{last} left shared test state changed (restored): #{Enum.join(leaks, "; ")}"
    end

    :ok
  end

  @doc "Restores a missing or stood-in orchestrator before a test and reports the test that ran before it."
  @spec ensure_running(map()) :: :ok | :error
  def ensure_running(context) do
    # Async neighbours may hold the name briefly; only a sync setup proves the previous test leaked it.
    leak = if context[:async], do: if(is_nil(Process.whereis(Aiur.Orchestrator)), do: "down"), else: leak()

    if leak do
      last = last_finished()
      IO.puts(:stderr, "Aiur.Orchestrator was #{leak} before #{test_name(context)}; last finished test: #{last || "unknown"}")
      unless context[:async], do: record_leak(last, leak)
      restore(leak)
    else
      RuntimeChildren.ensure_orchestrator_running()
    end
  end

  @doc """
  Raises when a sync test ends with the orchestrator down or its name held by
  a stand-in, after restoring it. Async tests are skipped: a concurrent sibling
  may hold the name briefly.
  """
  @spec verify_restored!(map()) :: :ok
  def verify_restored!(%{async: true}), do: :ok

  def verify_restored!(context) do
    # A call on the supervisor processes any child exit already in its mailbox.
    RuntimeChildren.supervisor_accepting_calls?(Process.whereis(Aiur.Supervisor), 1_000)

    if leak = leak() do
      restored = restore(leak)

      raise "#{test_name(context)} left Aiur.Orchestrator #{leak} (restore: #{inspect(restored)}). " <>
              "Restore it in on_exit with Aiur.TestSupport.ensure_orchestrator_running/0 or await_supervised_restart/3."
    end

    verify_shared_state_restored!(context)

    :ok
  end

  defp capture_app_env do
    Map.new(@guarded_app_env_keys, &{&1, Application.fetch_env(:aiur, &1)})
  end

  defp app_env_leaks do
    expected = :persistent_term.get(@app_env_key, capture_app_env())

    Enum.flat_map(@guarded_app_env_keys, fn key ->
      before = Map.fetch!(expected, key)
      current = Application.fetch_env(:aiur, key)
      if current == before, do: [], else: ["Application :aiur, #{inspect(key)} changed from #{inspect(before)} to #{inspect(current)}"]
    end)
  end

  defp verify_shared_state_restored!(%{aiur_expected_shared_state: expected} = context) do
    actual_instance_key = System.get_env("AIUR_INSTANCE_KEY")
    expected_instance_key = expected.instance_key

    app_env_leaks =
      Enum.flat_map(@guarded_app_env_keys, fn key ->
        before = Map.fetch!(expected.app_env, key)
        current = Application.fetch_env(:aiur, key)
        if current == before, do: [], else: ["Application :aiur, #{inspect(key)} changed from #{inspect(before)} to #{inspect(current)}"]
      end)

    instance_key_leaks = if actual_instance_key == expected_instance_key, do: [], else: ["AIUR_INSTANCE_KEY changed from #{inspect(expected_instance_key)} to #{inspect(actual_instance_key)}"]
    leaks = app_env_leaks ++ instance_key_leaks

    if leaks != [] do
      Enum.each(@guarded_app_env_keys, fn key -> restore_app_env(key, Map.fetch!(expected.app_env, key)) end)
      restore_instance_key(expected_instance_key)

      raise "#{test_name(context)} left shared test state changed (restored): #{Enum.join(leaks, "; ")}"
    end

    :ok
  end

  defp verify_shared_state_restored!(_context), do: :ok

  defp restore_app_env(key, :error), do: Application.delete_env(:aiur, key)
  defp restore_app_env(key, {:ok, value}), do: Application.put_env(:aiur, key, value)

  defp restore_instance_key(nil), do: System.delete_env("AIUR_INSTANCE_KEY")
  defp restore_instance_key(value), do: System.put_env("AIUR_INSTANCE_KEY", value)

  # nil when the name belongs to the supervised child, which is what every test expects to find.
  defp leak do
    case {Process.whereis(Aiur.Orchestrator), OrchestratorChild.supervised_pid()} do
      {nil, _child} -> "down"
      {pid, pid} -> nil
      {pid, _child} -> "held by a stand-in #{inspect(pid)}"
    end
  end

  defp restore("down"), do: RuntimeChildren.ensure_orchestrator_running()

  defp restore(_stand_in) do
    Process.unregister(Aiur.Orchestrator)
    RuntimeChildren.ensure_orchestrator_running()
  rescue
    # The stand-in exited and freed the name meanwhile.
    ArgumentError -> RuntimeChildren.ensure_orchestrator_running()
  end

  defp record_leak(name, leak),
    do: :persistent_term.put(@suite_leaks_key, :persistent_term.get(@suite_leaks_key, []) ++ ["#{name || "unknown"} (#{leak})"])

  defp last_finished do
    GenServer.call(__MODULE__, :last_finished, 1_000)
  catch
    :exit, _reason -> nil
  end

  defp test_name(context), do: "#{inspect(context[:module])}: #{context[:test]}"
end
