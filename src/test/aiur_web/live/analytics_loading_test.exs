defmodule AiurWeb.AnalyticsLoadingTest do
  use Aiur.TestSupport

  import Phoenix.ConnTest, except: [build_conn: 0]
  import Phoenix.LiveViewTest

  alias Aiur.RunTelemetry.RetainedCache
  alias Aiur.TestSupport.LiveViewAsync
  alias AiurWeb.Endpoint

  @endpoint Endpoint
  @summary Path.expand("../../fixtures/analytics/runs/boot-a/run-summary.json", __DIR__)

  setup context do
    root = Aiur.TestSupport.tmp_root!("analytics-loading")
    previous = for key <- [:repo_base_root, :analytics_repo, :analytics_telemetry_file, :analytics_rtk_opts, Endpoint], do: {key, Application.fetch_env(:aiur, key)}
    Application.put_env(:aiur, :repo_base_root, root)
    Application.put_env(:aiur, :analytics_repo, "test/analytics")
    Application.put_env(:aiur, :analytics_telemetry_file, Path.join(root, "missing.ndjson"))
    Application.put_env(:aiur, :analytics_rtk_opts, enabled?: false)

    Application.put_env(
      :aiur,
      Endpoint,
      Keyword.merge(Application.get_env(:aiur, Endpoint, []),
        server: false,
        secret_key_base: String.duplicate("s", 64),
        dashboard_writable: false,
        dashboard_auth_required: false,
        orchestrator: {:global, {__MODULE__, context.test}}
      )
    )

    Aiur.TestSupport.start_owned_endpoint!()

    on_exit(fn ->
      Aiur.TestSupport.restore_app_env(previous)
      Aiur.TestCleanup.rm_rf!(root)
    end)

    {:ok, root: root}
  end

  test "first HTTP response stays under five seconds and skips analysis" do
    started = System.monotonic_time(:millisecond)
    conn = get(build_conn(), "/analytics")
    elapsed = System.monotonic_time(:millisecond) - started
    assert elapsed < 5_000
    assert html_response(conn, 200) =~ "Loading run analytics"
    refute html_response(conn, 200) =~ "No run telemetry to analyze yet"
    IO.puts("cold /analytics HTTP response: #{elapsed} ms")
  end

  @tag timeout: 5_000
  test "concurrent mounts stay responsive during one blocked retained scan and both receive charts", %{root: root} do
    fifo = Path.join(root, "test/analytics/analytics/runs/prior/run-summary.json")
    File.mkdir_p!(Path.dirname(fifo))
    {_, 0} = System.cmd("mkfifo", [fifo])

    writer =
      Port.open({:spawn_executable, System.find_executable("python3")}, [
        :binary,
        :exit_status,
        args: ["-u", "-c", "import sys\nwith open(sys.argv[1], 'wb') as fifo:\n print('scan_started', flush=True)\n sys.stdin.readline()\n fifo.write(open(sys.argv[2], 'rb').read())", fifo, @summary]
      ])

    on_exit(fn -> if Port.info(writer), do: Port.close(writer) end)

    {:ok, first, html} = live(build_conn(), "/analytics")
    assert html =~ "Loading run analytics"
    receive_barrier({^writer, {:data, "scan_started\n"}})
    {:ok, second, html} = live(build_conn(), "/analytics")
    assert html =~ "Loading run analytics"
    assert render_click(first, "toggle-nav", %{}) =~ "Loading run analytics"
    Port.command(writer, "release\n")

    for view <- [first, second] do
      rendered = LiveViewAsync.render_when_complete(view)
      assert rendered =~ "Peak concurrency"
      assert rendered =~ ~s(data-source-kind="retained")
      refute rendered =~ "Loading run analytics"
    end

    # One FIFO write supplies both requests; a second scan would block forever.
    assert [{_, {[_dataset], false}}] = :ets.lookup(AiurWeb.OperatorControlCenter.Analytics.LatestRun, {RetainedCache.identity(Aiur.RunTelemetry.boot_id()), nil})
  end

  test "async worker exits become an unavailable state" do
    {:ok, view, _html} = live(build_conn(), "/analytics")
    LiveViewAsync.render_when_complete(view)
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, range: :run}}
    {:noreply, failed} = AiurWeb.AnalyticsLive.handle_async(:analytics_model, {:exit, :killed}, socket)
    assert failed.assigns.unavailable == :error
    assert failed.assigns.model == nil
  end

  defp build_conn do
    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("authorization", "Basic " <> Base.encode64("operator:test-dashboard-secret"))
  end
end
