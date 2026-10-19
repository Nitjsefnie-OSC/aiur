defmodule Aiur.RepoBase.BuildTimeoutTest do
  use Aiur.RepoBaseCase

  alias Aiur.Orchestrator.DispatchPolicy
  alias Aiur.RepoBase.BuildProcess

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
    pidfile = Path.join(tmp, "progressing-build.pid")
    pid = start_real_build(pid, cfg, tmp, origin, "echo $$ > #{pidfile}; sleep 30", dispatch_hold_timeout_ms: 40, build_hold_timeout_ms: 10_000)
    Phoenix.PubSub.subscribe(Aiur.PubSub, "prewarm:phase")

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    build_os_pid = await_file(pidfile, 500) |> String.trim() |> String.to_integer()
    state = wait_for_build_os_pid(pid, build_os_pid)
    os_pid = state.build.os_pid
    timer = state.build.timer

    refute_receive {:prewarm_phase, {:error, {:repo_base_build_hold_timeout, _}}}, 2_000
    assert %{phase: :building, build: %{os_pid: ^os_pid, timer: ^timer}} = :sys.get_state(pid)
    assert Aiur.ProcessTree.process_alive?(os_pid)
  end

  test "the production deadline kills the OS process tree, releases dispatch, and suppresses poll retries", %{
    server: pid,
    cfg: cfg,
    tmp: tmp,
    origin: origin
  } do
    pidfile = Path.join(tmp, "stalled-build-child.pid")
    command = "trap '' TERM; sleep 30 & echo $! > #{pidfile}; wait"
    pid = start_real_build(pid, cfg, tmp, origin, command, dispatch_hold_timeout_ms: 30, build_hold_timeout_ms: 10_000)
    Phoenix.PubSub.subscribe(Aiur.PubSub, "prewarm:phase")

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    state = wait_for_build_process(pid)
    child_pid = await_file(pidfile, 500) |> String.trim() |> String.to_integer()
    assert Aiur.ProcessTree.process_alive?(child_pid)

    assert_receive {:prewarm_phase, {:error, {:repo_base_build_hold_timeout, 10_000}}}, 12_000

    assert Task.async(fn -> GenServer.call(pid, :status) end) |> Task.await(1_000) |> elem(0) ==
             {:error, {:repo_base_build_hold_timeout, 10_000}}

    # A TERM-resistant group is given the reaper's full grace period before
    # SIGKILL, so allow the asynchronous cleanup to finish under CI load.
    wait_until(fn -> not Process.alive?(state.build.pid) and not Aiur.ProcessTree.process_alive?(child_pid) end, 7_000)
    refute Process.alive?(state.build.pid)
    refute Aiur.ProcessTree.process_alive?(child_pid)

    assert %{phase: {:error, {:repo_base_build_hold_timeout, 10_000}}, build: nil, dispatch_watchdog: nil} =
             :sys.get_state(pid)

    send(pid, :poll)
    assert %{phase: {:error, {:repo_base_build_hold_timeout, 10_000}}, build: nil} = :sys.get_state(pid)
    assert DispatchPolicy.prewarm_gate(true, GenServer.call(pid, :refresh_for_dispatch)) == :dispatch
  end

  test "the production deadline covers a stalled clone before build shell startup", %{server: pid, cfg: cfg, tmp: tmp, origin: origin} do
    git_bin = Path.join(tmp, "blocking-git")
    File.mkdir_p!(git_bin)
    pidfile = Path.join(tmp, "stalled-clone.pid")
    git_script = Path.join(git_bin, "git")

    File.write!(git_script, ~S"""
    #!/bin/sh
    if [ "$1" = clone ]; then
      echo $$ > "$AIUR_CLONE_PIDFILE"
      exec sleep 30
    fi
    exec /usr/bin/git "$@"
    """)

    File.chmod!(git_script, 0o755)

    pid =
      start_real_build(pid, cfg, tmp, origin, "true",
        dispatch_hold_timeout_ms: 25,
        build_hold_timeout_ms: 1_000,
        git_bin_dir: git_bin,
        clone_pidfile: pidfile,
        preclone: false
      )

    Phoenix.PubSub.subscribe(Aiur.PubSub, "prewarm:phase")

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    state = wait_for_build_process(pid)
    clone_pid = await_file(pidfile) |> String.trim() |> String.to_integer()
    assert Aiur.ProcessTree.process_alive?(clone_pid)

    assert_receive {:prewarm_phase, {:error, {:repo_base_build_hold_timeout, 1_000}}}, 3_000
    wait_until(fn -> not Aiur.ProcessTree.process_alive?(clone_pid) and not Process.alive?(state.build.pid) end, 800)
    refute Aiur.ProcessTree.process_alive?(clone_pid)
    assert %{phase: {:error, {:repo_base_build_hold_timeout, 1_000}}, build: nil} = :sys.get_state(pid)
  end

  test "stopping RepoBase terminates an active build process group", %{server: pid, cfg: cfg, tmp: tmp, origin: origin} do
    pidfile = Path.join(tmp, "stopped-server-child.pid")
    command = "sleep 30 & echo $! > #{pidfile}; wait"
    pid = start_real_build(pid, cfg, tmp, origin, command, dispatch_hold_timeout_ms: 30, build_hold_timeout_ms: 10_000)

    assert :building = GenServer.call(pid, :refresh_for_dispatch)
    state = wait_for_build_process(pid)
    child_pid = await_file(pidfile, 500) |> String.trim() |> String.to_integer()
    assert Aiur.ProcessTree.process_alive?(child_pid)

    :ok = GenServer.stop(pid, :normal)
    wait_until(fn -> not Aiur.ProcessTree.process_alive?(child_pid) and not Process.alive?(state.build.pid) end, 7_000)
    refute Aiur.ProcessTree.process_alive?(child_pid)
  end

  def clone_url_for_test(origin), do: origin

  defp start_real_build(pid, cfg, tmp, origin, command, opts) do
    root = Path.join(tmp, "repo-base-root")
    previous_root = Application.get_env(:aiur, :repo_base_root)
    previous_clone_url = Application.get_env(:aiur, :repo_base_clone_url)
    previous_path = System.get_env("PATH")
    previous_clone_pidfile = System.get_env("AIUR_CLONE_PIDFILE")
    real_git = System.get_env("AIUR_REAL_GIT") || "/usr/bin/git"
    {:ok, tracker} = Agent.start(fn -> %{} end)
    Process.put({__MODULE__, :process_tracker}, tracker)
    if clone_pidfile = Keyword.get(opts, :clone_pidfile), do: System.put_env("AIUR_CLONE_PIDFILE", clone_pidfile)
    Application.put_env(:aiur, :repo_base_root, root)
    Application.put_env(:aiur, :repo_base_clone_url, {__MODULE__, :clone_url_for_test, [origin]})
    if Keyword.get(opts, :preclone, true), do: preclone_base!(real_git, origin)
    git_bin_dir = Keyword.get(opts, :git_bin_dir)
    path_prefix = if git_bin_dir, do: git_bin_dir <> ":", else: ""
    System.put_env("PATH", path_prefix <> Path.dirname(real_git) <> ":" <> previous_path)

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

    server_opts =
      opts
      |> Keyword.drop([:git_bin_dir, :clone_pidfile, :preclone])
      |> Keyword.put_new(:remote_head_fun, fn _repo_url -> Process.sleep(:infinity) end)

    {:ok, server} = GenServer.start_link(Aiur.RepoBase, server_opts)

    on_exit(fn ->
      BuildProcess.terminate_processes(Agent.get(tracker, & &1))

      case Process.alive?(server) && :sys.get_state(server) do
        %{build: %{pid: worker_pid} = build} ->
          BuildProcess.terminate_processes(build.os_processes)
          kill_worker(worker_pid)

        _ ->
          :ok
      end

      Aiur.TestSupport.safe_stop(server)
      restore_env(:repo_base_root, previous_root)
      restore_env(:repo_base_clone_url, previous_clone_url)
      System.put_env("PATH", previous_path)
      restore_system_env("AIUR_CLONE_PIDFILE", previous_clone_pidfile)
      Agent.stop(tracker)
    end)

    server
  end

  defp restore_env(key, nil), do: Application.delete_env(:aiur, key)
  defp restore_env(key, value), do: Application.put_env(:aiur, key, value)
  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
  defp kill_worker(pid), do: if(Process.alive?(pid), do: Process.exit(pid, :kill))

  defp preclone_base!(git, origin) do
    base = Aiur.RepoBase.base_path(origin)
    File.mkdir_p!(Path.dirname(base))
    {_output, 0} = System.cmd(git, ["clone", "--branch", "main", origin, base], stderr_to_stdout: true)
  end

  defp wait_for_build_process(pid, attempts \\ 100)
  defp wait_for_build_process(_pid, 0), do: flunk("RepoBase did not start the build command")

  defp wait_for_build_process(pid, attempts) do
    case :sys.get_state(pid) do
      %{build: %{os_pid: os_pid, timer: timer} = build} = state when is_integer(os_pid) and is_reference(timer) ->
        tracker = Process.get({__MODULE__, :process_tracker})

        if Map.has_key?(build.os_processes, os_pid) do
          Agent.update(tracker, &Map.merge(&1, build.os_processes))
          %{state | build: build}
        else
          Process.sleep(10)
          wait_for_build_process(pid, attempts - 1)
        end

      _ ->
        Process.sleep(10)
        wait_for_build_process(pid, attempts - 1)
    end
  end

  defp wait_for_build_os_pid(pid, expected_os_pid, attempts \\ 100)
  defp wait_for_build_os_pid(_pid, _expected_os_pid, 0), do: flunk("RepoBase did not register the expected build process")

  defp wait_for_build_os_pid(pid, expected_os_pid, attempts) do
    case :sys.get_state(pid) do
      %{build: %{os_pid: ^expected_os_pid, timer: timer} = build} = state when is_reference(timer) ->
        tracker = Process.get({__MODULE__, :process_tracker})
        Agent.update(tracker, &Map.merge(&1, build.os_processes))
        %{state | build: build}

      _ ->
        Process.sleep(10)
        wait_for_build_os_pid(pid, expected_os_pid, attempts - 1)
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
