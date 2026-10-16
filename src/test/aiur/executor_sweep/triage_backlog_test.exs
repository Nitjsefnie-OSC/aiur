defmodule Aiur.ExecutorSweep.TriageBacklogTest do
  use ExUnit.Case, async: true

  alias Aiur.ExecutorSweep
  alias Aiur.ExecutorSweep.{Checks, TriageBacklog}
  alias Aiur.OpenTicketSource.Snapshot

  @now ~U[2026-10-16 12:00:00Z]

  defp ticket(id, labels, created_at), do: %{identifier: id, labels: labels, created_at: created_at}

  test "status counts only needs-triage tickets older than an hour and names the oldest" do
    snapshot = %Snapshot{
      status: :available,
      tickets: [
        ticket("4466", ["needs-triage"], ~U[2026-10-15 09:00:00Z]),
        ticket("4500", ["needs-triage", "bug"], ~U[2026-10-16 10:30:00Z]),
        ticket("4510", ["needs-triage"], ~U[2026-10-16 11:30:00Z]),
        ticket("4511", ["agent:todo"], ~U[2026-10-15 09:00:00Z])
      ]
    }

    assert TriageBacklog.status_line(snapshot, @now) == "TRIAGE needs-triage >1h 2 (oldest #4466 27h)"
  end

  test "status reports zero, stale, and unavailable projections honestly" do
    assert TriageBacklog.status_line(%Snapshot{status: :available}, @now) == "TRIAGE needs-triage >1h 0"
    assert TriageBacklog.status_line(%Snapshot{status: :stale}, @now) == "TRIAGE needs-triage >1h 0 STALE"
    assert TriageBacklog.status_line(%Snapshot{status: :unavailable}, @now) =~ "TRIAGE unavailable"
  end

  test "a growing stale-triage backlog wakes the Executor for each new ticket" do
    parent = self()
    {:ok, tickets} = Agent.start_link(fn -> [%{number: 1, labels: ["needs-triage"], created_at: ~U[2026-10-16 09:00:00Z]}] end)
    sweep = fn -> Checks.all(%{tickets: Agent.get(tickets, & &1)}, @now) |> Enum.filter(&(&1.kind == "stale_needs_triage")) end

    assert {:ok, pid} = ExecutorSweep.start_link(name: nil, interval_ms: 60_000, sweep_fun: sweep, publish_fun: &send(parent, {:finding, &1}))
    assert_receive {:finding, %{kind: "stale_needs_triage", ticket: 1}}, 1_000

    Agent.update(tickets, &[%{number: 2, labels: ["needs-triage"], created_at: ~U[2026-10-16 10:00:00Z]} | &1])
    send(pid, :sweep)
    assert_receive {:finding, %{kind: "stale_needs_triage", ticket: 2}}, 1_000
    refute_receive {:finding, %{ticket: 1}}, 50

    GenServer.stop(pid)
    Agent.stop(tickets)
  end
end
