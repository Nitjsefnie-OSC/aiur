defmodule Aiur.ShutdownHandoffCleanupTest do
  use Aiur.TestSupport, async: false

  alias Aiur.{ProcessTree, Shutdown, Tmux}
  alias Aiur.Handoff.Protection

  defmodule PaneServer do
    use GenServer
    def start_link(windows), do: GenServer.start_link(__MODULE__, windows)
    def init(windows), do: {:ok, windows}
    def handle_call({:on_socket, _socket, message}, from, state), do: handle_call(message, from, state)
    def handle_call(:list_windows, _from, state), do: {:reply, {:ok, state}, state}
    def handle_call({:pane_pid, _pane}, _from, state), do: {:reply, {:error, :no_pane}, state}
    def handle_call({:kill_pane, pane}, _from, state), do: {:reply, :ok, Enum.reject(state, fn {_name, id} -> id == pane end)}
  end

  setup do
    reaper = Process.whereis(Aiur.ProcessReaper)
    draining = :sys.get_state(reaper).draining

    on_exit(fn ->
      if Process.alive?(reaper), do: :sys.replace_state(reaper, &%{&1 | draining: draining})
      Protection.reset()
    end)

    :ok
  end

  test "cleanup keeps the handed-off pane and still sweeps fallback and unlisted panes" do
    prefix = "aiur-repl-#{System.pid()}-"
    server = start_supervised!({PaneServer, [{prefix <> "1", "%held"}, {prefix <> "2", "%fallback"}, {prefix <> "3", "%unlisted"}]})
    tmux = {:socket, server, "handoff-agents"}

    protect([
      %{"identifier" => "held", "transport" => %{"pane_id" => "%held", "socket" => "handoff-agents"}},
      %{"identifier" => "fallback", "fallback_reason" => "config_changed", "transport" => %{"pane_id" => "%fallback", "socket" => "handoff-agents"}}
    ])

    assert :ok = Shutdown.cleanup(100, tmux: tmux)
    assert {:ok, [{name, "%held"}]} = Tmux.list_windows(tmux)
    assert name == prefix <> "1"
  end

  @tag :real_proc
  test "cleanup keeps the handed-off process tree and reaps fallback and unlisted workspace processes" do
    root = Aiur.TestSupport.tmp_root!("shutdown-handoff-processes")
    workspace = Path.join(root, "ticket")
    File.mkdir_p!(workspace)
    write_workflow_file!(Workflow.workflow_file_path(), workspace_root: root)
    WorkflowStore.force_reload()
    previous = Application.get_env(:aiur, :headless)
    Application.put_env(:aiur, :headless, true)
    on_exit(fn -> Application.put_env(:aiur, :headless, previous) end)

    held = spawn_tree(workspace)
    fallback = spawn_tree(workspace)
    unlisted = spawn_tree(workspace)
    children = await_children(held, 100)
    assert children != []
    protect([%{"identifier" => "held", "transport" => %{"provider_pid" => held}}, %{"identifier" => "fallback", "fallback_reason" => "config_changed", "transport" => %{"provider_pid" => fallback}}])
    server = start_supervised!({PaneServer, []})

    assert :ok = Shutdown.cleanup(100, tmux: server, workspace_reap_opts: [backoff_ms: 10])
    assert ProcessTree.process_alive?(held)
    assert Enum.all?(children, &ProcessTree.process_alive?/1)
    refute ProcessTree.process_alive?(fallback)
    refute ProcessTree.process_alive?(unlisted)
  end

  defp protect(agents) do
    Protection.store(self(), %{agents: agents}, MapSet.new(["held"]))
  end

  defp spawn_tree(cwd) do
    {output, 0} = System.cmd("sh", ["-c", "cd \"$1\" || exit 1; sh -c 'sleep 300 & wait' >/dev/null 2>&1 & echo $!", "sh", cwd])
    pid = output |> String.trim() |> String.to_integer()
    on_exit(fn -> ProcessTree.graceful_kill_tree(pid) end)
    pid
  end

  defp await_children(_pid, 0), do: []

  defp await_children(pid, attempts) do
    case ProcessTree.process_tree(pid) -- [pid] do
      [] ->
        Process.sleep(10)
        await_children(pid, attempts - 1)

      children ->
        children
    end
  end
end
