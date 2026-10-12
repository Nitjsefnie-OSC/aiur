defmodule Aiur.Orchestrator.OptimisticGuardEffectsTest do
  use Aiur.TestSupport

  alias Aiur.{Config, Issue}
  alias Aiur.BuildQueue.{Attention, Store}
  alias Aiur.Events.Exchange
  alias Aiur.Orchestrator.{OptimisticGuardEffects, OptimisticLedger, State}

  @topic "ticket.11.queue.attention.optimistic_blocker_failed"
  @park {:park, "11", "10", :pr_closed_unmerged}

  setup do
    :ok = Supervisor.terminate_child(Aiur.Supervisor, OptimisticLedger)
    on_exit(fn -> Supervisor.restart_child(Aiur.Supervisor, OptimisticLedger) end)
    root = Aiur.TestSupport.tmp_root!("optimistic-guard-effects")
    path = Path.join(root, "starts.json")
    previous = Application.fetch_env(:aiur, :decision_state_dir)
    Application.put_env(:aiur, :decision_state_dir, root)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:aiur, :decision_state_dir, value)
        :error -> Application.delete_env(:aiur, :decision_state_dir)
      end

      Aiur.TestCleanup.rm_rf!(root)
    end)

    start_ledger(path)

    assert :ok =
             OptimisticLedger.record_start("11", %{
               attempt_id: "guard-effects",
               start_trigger: :pr_opened,
               started_at_ms: 100,
               blockers: [%{"id" => "10", "pr_number" => 77, "pr_state" => "open", "pr_head_ref_at_start" => "refs/heads/aiur/10-blocker", "pr_head_sha_at_start" => "original"}]
             })

    :ok = Exchange.subscribe(@topic <> ".#")
    {:ok, path: path, opts: effect_options()}
  end

  test "restart between pause and label resumes the park without repeating pause or comment", %{path: path, opts: opts} do
    failed_label = fn "11", "agent:parked" -> {:error, :offline} end
    state = OptimisticGuardEffects.execute(running(), @park, Keyword.put(opts, :label, failed_label))
    assert_received {:effect, :pause}
    assert blocker()["pause_complete"] == true
    assert blocker()["label_complete"] != true
    refute_received {:effect, :comment}
    refute_received {:event, %{topic: @topic}}

    stop_supervised!(OptimisticLedger)
    start_ledger(path)
    state = OptimisticGuardEffects.execute(state, @park, opts)
    assert_received {:effect, :label}
    assert_received {:effect, :draft}
    assert_received {:effect, :comment}
    assert_received {:event, %{topic: @topic, blocker: "10", cause: :pr_closed_unmerged, action: :paused_parked}}
    refute_received {:effect, :pause}
    assert_complete()

    OptimisticGuardEffects.execute(state, @park, opts)
    refute_received {:effect, :pause}
    refute_received {:effect, :label}
    refute_received {:effect, :draft}
    refute_received {:effect, :comment}
    refute_received {:event, %{topic: @topic}}
    assert {:ok, %{latches: [latch]}} = Store.load()
    assert latch.key == {:optimistic_blocker_failed, "11"}
    assert latch.emitted?
  end

  test "global pause leaves pause pending and completes parking after resume", %{opts: opts} do
    state = %{running() | globally_paused: true}
    state = OptimisticGuardEffects.execute(state, @park, opts)
    refute_received {:effect, :pause}
    assert blocker()["pause_complete"] != true
    assert blocker()["park_complete"] != true
    assert_received {:effect, :label}
    assert_received {:effect, :draft}
    assert_received {:effect, :comment}
    assert_received {:event, %{topic: @topic, action: :paused_parked}}

    state = %{state | globally_paused: false}
    OptimisticGuardEffects.execute(state, @park, opts)
    assert_received {:effect, :pause}
    refute_received {:effect, :comment}
    refute_received {:event, %{topic: @topic}}
    assert_complete()
  end

  test "a finished dependent is parked with no pause and a parked action", %{opts: opts} do
    OptimisticGuardEffects.execute(%State{}, @park, opts)
    refute_received {:effect, :pause}
    assert_received {:effect, :label}
    assert_received {:effect, :draft}
    assert_received {:effect, :comment}
    assert_received {:event, %{topic: @topic, action: :parked}}
    assert_complete()
  end

  test "poll reconciliation reads a closed blocker and parks one tick beyond grace", %{opts: opts} do
    {:ok, clock} = Agent.start_link(fn -> 1_000 end)
    test_pid = self()

    opts =
      Keyword.merge(opts,
        settings: Config.settings!(),
        clock: fn -> Agent.get(clock, & &1) end,
        grace_ms: 10,
        observation_max_age_ms: 1,
        blocked_by: fn "11" -> {:ok, ["10"]} end,
        fetch_issues: fn ["10"] -> {:ok, [%Issue{id: "10", identifier: "10", state: "in-progress"}]} end,
        closure: fn "10", 1 -> {:ok, %{open?: true, state_reason: nil}} end,
        read_pr: fn "10", 77 ->
          send(test_pid, {:effect, :read_pr})
          {:ok, %{"number" => 77, "state" => "closed", "merged" => false, "head" => %{"ref" => "aiur/10-blocker", "sha" => "original"}}}
        end
      )

    issue = %Issue{id: "10", identifier: "10", state: "in-progress"}
    state = OptimisticGuardEffects.reconcile(%{running() | last_polled_issues: %{"10" => issue}}, opts)
    assert_received {:effect, :read_pr}
    refute_received {:effect, :pause}
    refute_received {:event, %{topic: @topic}}
    assert blocker()["suspect_since_ms"] == 1_000
    assert blocker()["guard_observation"]["pr_merged"] == false

    Agent.update(clock, fn _ -> 1_011 end)
    state = OptimisticGuardEffects.reconcile(state, opts)
    assert_received {:effect, :read_pr}
    assert_received {:effect, :pause}
    assert_received {:effect, :label}
    assert_received {:effect, :draft}
    assert_received {:effect, :comment}
    assert_received {:event, %{topic: @topic, action: :paused_parked}}
    assert_complete()

    OptimisticGuardEffects.reconcile(state, opts)
    refute_received {:effect, :pause}
    refute_received {:effect, :comment}
    refute_received {:event, %{topic: @topic}}
    Agent.stop(clock)
  end

  defp start_ledger(path), do: start_supervised!({OptimisticLedger, [path: path]})

  defp running do
    issue = %Issue{id: "11", identifier: "11", state: "in-progress"}
    %State{running: %{"11" => %{identifier: "11", issue: issue, control: %{status: :working}}}}
  end

  defp effect_options do
    test_pid = self()

    [
      ledger: OptimisticLedger,
      label_prefix: "agent",
      clock: fn -> 1_000 end,
      pause: fn state, %{identifier: "11"} ->
        send(test_pid, {:effect, :pause})
        entry = put_in(state.running["11"], [:control, :status], :paused)
        {{:ok, 1}, %{state | running: Map.put(state.running, "11", entry)}}
      end,
      label: fn "11", "agent:parked" ->
        send(test_pid, {:effect, :label})
        :ok
      end,
      draft: fn "11" ->
        send(test_pid, {:effect, :draft})
        :ok
      end,
      comment: fn "11", "10", cause when cause in [:pr_closed_unmerged, "pr_closed_unmerged"] ->
        send(test_pid, {:effect, :comment})
        :ok
      end,
      attention: fn
        :open, dep, payload -> Attention.open(:optimistic_blocker_failed, dep, payload)
        :resolve, dep, _payload -> Attention.resolve(:optimistic_blocker_failed, dep)
      end
    ]
  end

  defp blocker do
    assert {:ok, row} = OptimisticLedger.get("11")
    hd(row["blockers"])
  end

  defp assert_complete do
    assert {:ok, row} = OptimisticLedger.get("11")
    assert row["status"] == "parked"
    assert row["counters"]["parks"] == 1
    facts = hd(row["blockers"])
    assert facts["pause_complete"] == true
    assert facts["label_complete"] == true
    assert facts["draft_complete"] == true
    assert facts["comment_complete"] == true
    assert facts["park_complete"] == true
  end
end
