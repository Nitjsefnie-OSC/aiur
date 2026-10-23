defmodule Aiur.Orchestrator.SharedLeaseDispatchTest do
  use Aiur.DispatcherTestSupport

  alias Aiur.Instance.LeaseStore
  alias Aiur.Orchestrator.{Dispatcher, State}

  test "two dispatcher instances race through launch and start only one runner" do
    parent = self()
    {:ok, leases} = Agent.start_link(fn -> MapSet.new() end)
    on_exit(fn -> if Process.alive?(leases), do: Agent.stop(leases) end)

    claim_fun = fn issue ->
      {:ok, key} = LeaseStore.ticket_key(issue)
      send(parent, {:lease_claimed, key})

      Agent.get_and_update(leases, fn held ->
        if MapSet.member?(held, key),
          do: {:held, held},
          else: {:acquired, MapSet.put(held, key)}
      end)
    end

    issue = %Aiur.Issue{
      id: "42",
      identifier: "42",
      tracker_identity: %Aiur.TrackerIdentity{
        status: :joinable,
        kind: :github,
        owner: "Acme",
        repository: "Widgets",
        provider_id: "issue-node-42",
        identifier: "42",
        reason: nil
      },
      state: "todo",
      selected_backend: "codex"
    }

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          Dispatcher.do_dispatch_issue(
            %State{max_concurrent_agents: 1, effective_concurrent_agents: 1},
            issue,
            nil,
            nil,
            lease_claim_fun: claim_fun,
            runner: fn dispatched, _, _ ->
              send(parent, {:runner_started, dispatched.id})
              :ok
            end
          )
        end)
      end

    states = Enum.map(tasks, &Task.await(&1, 2_000))

    assert_receive {:lease_claimed, "acme/widgets#42"}, 1_000
    assert_receive {:lease_claimed, "acme/widgets#42"}, 1_000
    assert Enum.count(states, &MapSet.member?(&1.claimed, issue.id)) == 1
    assert_receive {:runner_started, "42"}, 1_000
    refute_receive {:runner_started, "42"}, 100
  end

  test "dispatch eligibility is checked before acquiring the shared lease" do
    parent = self()
    issue = %{issue("held-before-lease") | selected_backend: "codex"}

    Process.put({Aiur.Handoff, :dispatch_hold}, true)

    state =
      try do
        Dispatcher.do_dispatch_issue(
          %State{max_concurrent_agents: 1, effective_concurrent_agents: 1},
          issue,
          nil,
          nil,
          lease_claim_fun: fn _ ->
            send(parent, :lease_claimed)
            :acquired
          end,
          runner: fn _, _, _ -> :ok end
        )
      after
        Process.delete({Aiur.Handoff, :dispatch_hold})
      end

    refute_receive :lease_claimed, 0
    refute MapSet.member?(state.claimed, issue.id)
  end

  test "a lease acquired for a launch that cannot start is released" do
    parent = self()

    issue = %Aiur.Issue{
      id: "43",
      identifier: "43",
      tracker_identity: %Aiur.TrackerIdentity{
        status: :joinable,
        kind: :github,
        owner: "Acme",
        repository: "Widgets",
        provider_id: "issue-node-43",
        identifier: "43",
        reason: nil
      },
      state: "todo",
      selected_backend: "codex"
    }

    state =
      Dispatcher.do_dispatch_issue(
        %State{max_concurrent_agents: 1, effective_concurrent_agents: 1},
        issue,
        nil,
        nil,
        lease_claim_fun: fn _ -> :acquired end,
        lease_release_fun: fn ticket ->
          send(parent, {:lease_released, ticket})
          :ok
        end,
        start_runner_task_fun: fn _issue, _runner, _recipient, _context, _opts ->
          {:error, :controlled_spawn_failure}
        end
      )

    assert_receive {:lease_released, ^issue}, 1_000
    refute MapSet.member?(state.claimed, issue.id)
  end
end
