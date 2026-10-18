defmodule AiurEngineHandoffReportTest do
  use ExUnit.Case, async: true

  import Aiur.TestSupport.EngineCase

  test "restart continues when the release has no epmd executable" do
    release = Aiur.TestSupport.tmp_root!("restart-no-epmd-binary")
    File.mkdir_p!(release)
    on_exit(fn -> Aiur.TestCleanup.rm_rf!(release) end)

    {out, 0} =
      run_sourced_engine(
        "release_dir=#{inspect(release)}; probe_node_liveness() { printf unknown; }; wait_for_node_name_release 'aiur-test@127.0.0.1' && echo RELEASED",
        []
      )

    assert out =~ "release has no epmd binary"
    assert out =~ "RELEASED"
  end

  test "successful restart reports lost handoff sessions" do
    {out, 0} =
      run_sourced_engine(
        """
        run_control_rpc() {
          case "$1" in
            *prepare*) echo '__AIUR_HANDOFF__:handoff-success' ;;
            *report*) echo 'HANDOFF handoff-success adopted=0 fallback=3 gap=104064ms'; echo 'ticket-1 fallback relay_gone' ;;
          esac
        }
        cmd_stop() { :; }
        dispatch_run() { echo RUN; }
        cmd_restart --keep-agents --no-build
        """,
        []
      )

    assert out =~ "3 handoff session(s) lost: relay_gone"
    assert out =~ "adopted=0 fallback=3 gap=104064ms"
  end
end
