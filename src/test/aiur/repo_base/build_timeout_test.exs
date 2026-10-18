defmodule Aiur.RepoBase.BuildTimeoutTest do
  use Aiur.RepoBaseCase

  alias Aiur.Orchestrator.DispatchPolicy

  setup do
    tmp = Aiur.TestSupport.tmp_root!("rb_timeout_cfg")
    File.mkdir_p!(tmp)
    cfg = Path.join(tmp, "config")
    File.write!(cfg, "tracker:\n  kind: memory\n")
    previous_path = Application.get_env(:aiur, :workflow_file_path)
    Aiur.Workflow.set_workflow_file_path(cfg)
    {:ok, server} = GenServer.start_link(Aiur.RepoBase, [])

    on_exit(fn ->
      Aiur.TestSupport.safe_stop(server)

      case previous_path do
        nil -> Aiur.Workflow.clear_workflow_file_path()
        path -> Aiur.Workflow.set_workflow_file_path(path)
      end

      Aiur.TestCleanup.rm_rf!(tmp)
    end)

    {:ok, server: server, cfg: cfg}
  end

  test "a real progressing build remains alive across idle watchdog re-arms", %{server: pid, cfg: cfg, tmp: tmp, origin: origin} do
    pid = start_real_build(pid, cfg, tmp, origin, "sleep 30", dispatch_hold_timeout_ms: 40, build_hold_timeout_ms: 1_200)
    Phoenix.PubSub.subscribe(Aiur.PubSub, "prewarm:phase")

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    state = wait_for_build_process(pid)
    os_pid = state.build.os_pid

    refute_receive {:prewarm_phase, {:error, {:repo_base_build_hold_timeout, _}}}, 700
    assert %{phase: :building, build: %{os_pid: ^os_pid, timer: timer}} = :sys.get_state(pid)
    assert is_reference(timer)
    assert Aiur.ProcessTree.process_alive?(os_pid)
  end

  test "the production deadline kills the OS process tree, releases dispatch, and suppresses poll retries", %{
    server: pid,
    cfg: cfg,
    tmp: tmp,
    origin: origin
  } do
    pidfile = Path.join(tmp, "stalled-build-child.pid")
    command = "sleep 30 & echo $! > #{pidfile}; wait"
    pid = start_real_build(pid, cfg, tmp, origin, command, dispatch_hold_timeout_ms: 30, build_hold_timeout_ms: 500)
    Phoenix.PubSub.subscribe(Aiur.PubSub, "prewarm:phase")

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    state = wait_for_build_process(pid)
    child_pid = await_file(pidfile) |> String.trim() |> String.to_integer()
    assert Aiur.ProcessTree.process_alive?(child_pid)

    assert_receive {:prewarm_phase, {:error, {:repo_base_build_hold_timeout, 500}}}, 3_000
    wait_until(fn -> not Process.alive?(state.build.pid) and not Aiur.ProcessTree.process_alive?(child_pid) end)
    refute Process.alive?(state.build.pid)
    refute Aiur.ProcessTree.process_alive?(child_pid)

    assert %{phase: {:error, {:repo_base_build_hold_timeout, 500}}, build: nil, dispatch_watchdog: nil} =
             :sys.get_state(pid)

    send(pid, :poll)
    assert %{phase: {:error, {:repo_base_build_hold_timeout, 500}}, build: nil} = :sys.get_state(pid)
    assert DispatchPolicy.prewarm_gate(true, GenServer.call(pid, :refresh_for_dispatch)) == :dispatch
  end

  def clone_url_for_test(origin), do: origin

  defp start_real_build(pid, cfg, tmp, origin, command, opts) do
    root = Path.join(tmp, "repo-base-root")
    previous_root = Application.get_env(:aiur, :repo_base_root)
    previous_clone_url = Application.get_env(:aiur, :repo_base_clone_url)
    previous_path = System.get_env("PATH")
    real_git = System.get_env("AIUR_REAL_GIT") || "/usr/bin/git"
    Application.put_env(:aiur, :repo_base_root, root)
    Application.put_env(:aiur, :repo_base_clone_url, {__MODULE__, :clone_url_for_test, [origin]})
    System.put_env("PATH", Path.dirname(real_git) <> ":" <> previous_path)

    Aiur.TestSupport.safe_stop(pid)

    File.write!(cfg, """
    tracker:
      kind: github
      base_branch: main
      github:
        repo: owner/project
    prewarm:
      enabled: true
      base_build: #{Jason.encode!(command)}
      poll_seconds: 0
    """)

    :ok = Aiur.WorkflowStore.force_reload()
    server_opts = Keyword.put_new(opts, :remote_head_fun, fn _repo_url -> Process.sleep(:infinity) end)
    {:ok, server} = GenServer.start_link(Aiur.RepoBase, server_opts)

    on_exit(fn ->
      case Process.alive?(server) && :sys.get_state(server) do
        %{build: %{pid: worker_pid, os_pid: os_pid}} ->
          Aiur.ProcessTree.graceful_kill_tree(os_pid)
          kill_worker(worker_pid)

        _ ->
          :ok
      end

      Aiur.TestSupport.safe_stop(server)
      restore_env(:repo_base_root, previous_root)
      restore_env(:repo_base_clone_url, previous_clone_url)
      System.put_env("PATH", previous_path)
    end)

    server
  end

  defp restore_env(key, nil), do: Application.delete_env(:aiur, key)
  defp restore_env(key, value), do: Application.put_env(:aiur, key, value)
  defp kill_worker(pid), do: if(Process.alive?(pid), do: Process.exit(pid, :kill))

  defp wait_for_build_process(pid, attempts \\ 100)
  defp wait_for_build_process(_pid, 0), do: flunk("RepoBase did not start the build command")

  defp wait_for_build_process(pid, attempts) do
    case :sys.get_state(pid) do
      %{build: %{os_pid: os_pid, timer: timer} = build} = state when is_integer(os_pid) and is_reference(timer) ->
        %{state | build: build}

      _ ->
        Process.sleep(10)
        wait_for_build_process(pid, attempts - 1)
    end
  end

  defp await_file(path, attempts \\ 100)
  defp await_file(_path, 0), do: flunk("build command did not create its pid file")

  defp await_file(path, attempts) do
    case File.read(path) do
      {:ok, contents} ->
        contents

      _ ->
        Process.sleep(10)
        await_file(path, attempts - 1)
    end
  end

  defp wait_until(predicate, attempts \\ 100)
  defp wait_until(_predicate, 0), do: flunk("condition was not reached")

  defp wait_until(predicate, attempts) do
    if predicate.() do
      :ok
    else
      Process.sleep(10)
      wait_until(predicate, attempts - 1)
    end
  end
end
