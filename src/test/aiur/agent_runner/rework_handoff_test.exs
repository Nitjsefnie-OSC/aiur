defmodule Aiur.AgentRunner.ReworkHandoffTest do
  use Aiur.TestSupport

  alias Aiur.AgentRunner.TurnLoop
  alias Aiur.Workspace.Provisioner

  defmodule FakeOrchestrator do
    use GenServer

    def start_link, do: GenServer.start_link(__MODULE__, nil)
    @impl true
    def init(state), do: {:ok, state}
    @impl true
    def handle_call({:claim_next_queue_item, _identifier}, _from, state), do: {:reply, :empty, state}
    def handle_call({:consume_delivered_queue_items, _identifier}, _from, state), do: {:reply, :ok, state}
    def handle_call({:restore_delivered_queue_items, _identifier}, _from, state), do: {:reply, :ok, state}
    def handle_call({:fail_delivered_queue_items, _identifier, _reason}, _from, state), do: {:reply, :ok, state}
  end

  test "a productive rework turn with a new PR head hands off instead of starting another turn" do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(),
      tracker_kind: "memory",
      tracker_active_states: ["todo", "in-progress", "rework"]
    )

    Aiur.WorkflowStore.force_reload()
    Application.put_env(:aiur, :memory_tracker_recipient, self())
    root = Aiur.TestSupport.tmp_root!("rework-handoff")
    workspace = Path.join(root, "ws")
    File.mkdir_p!(workspace)
    assert :ok = Provisioner.maybe_install_agent_support(workspace, nil)
    {:ok, orchestrator} = FakeOrchestrator.start_link()
    {:ok, turns} = Agent.start_link(fn -> 0 end)
    identifier = "614309"
    issue = %Aiur.Issue{id: "gid-#{identifier}", identifier: identifier, state: "rework", labels: ["agent:rework"]}

    on_exit(fn -> Aiur.TestCleanup.rm_rf!(root) end)

    assert {:completed, %{state: "human-review"}} =
             TurnLoop.run_turns(
               %{backend: "claude", workspace: workspace, worker_host: nil},
               workspace,
               issue,
               nil,
               [
                 resumed: true,
                 run_turn: fn _session, _prompt, _issue, _opts ->
                   Agent.update(turns, &(&1 + 1))
                   {:ok, %{session_id: "productive-rework"}}
                 end,
                 workspace_probe: fn _workspace, _worker_host -> {:ok, "workspace"} end,
                 rework_head_sha: "reviewed-head",
                 open_pr_fetcher: fn _ -> {:ok, %{"head" => %{"sha" => "fixed-head"}}} end,
                 commit_ci_status_fetcher: fn _ -> {:ok, %{check_runs: [], commit_status: %{"state" => "success"}}} end
               ],
               fn _ids -> {:ok, [issue]} end,
               orchestrator,
               nil,
               1,
               nil
             )

    assert Agent.get(turns, & &1) == 1
    assert_receive {:memory_tracker_state_update, ^identifier, "human-review"}, 1000
  end
end
