defmodule Aiur.ExecutorSweep.TriageBacklogTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Aiur.ExecutorAttention.CLI
  alias Aiur.ExecutorSweep
  alias Aiur.ExecutorSweep.{Checks, TriageBacklog}
  alias Aiur.OpenTicketSource.Snapshot

  @now ~U[2026-10-16 12:00:00Z]

  defp ticket(id, labels, created_at), do: %{identifier: id, labels: labels, created_at: created_at}

  defp line(fields), do: TriageBacklog.status_line(struct(Snapshot, fields), @now)

  test "status counts only needs-triage tickets older than an hour and names the oldest" do
    tickets = [
      ticket("4466", ["needs-triage"], ~U[2026-10-15 09:00:00Z]),
      ticket("4500", ["needs-triage", "bug"], ~U[2026-10-16 10:30:00Z]),
      ticket("4510", ["needs-triage"], ~U[2026-10-16 11:30:00Z]),
      ticket("4511", ["agent:todo"], ~U[2026-10-15 09:00:00Z])
    ]

    assert line(status: :available, tickets: tickets) == "TRIAGE needs-triage >1h 2 (oldest #4466 27h)"
  end

  test "status names each projection state on its own" do
    assert line(status: :available) == "TRIAGE needs-triage >1h 0"
    assert line(status: :stale, observed_at: ~U[2026-10-16 11:46:00Z]) == "TRIAGE needs-triage >1h 0 STALE observed 14m ago"
    assert line(status: :stale) == "TRIAGE needs-triage >1h 0 STALE observed age unknown"
    assert line(status: :unavailable) == "TRIAGE unavailable (the open-ticket listing is not loaded)"
    assert line(status: :unsupported) == "TRIAGE unsupported (tracker has no open-ticket listing)"
  end

  test "a truncated listing is a lower bound and unknown ages are counted" do
    tickets = [ticket("1", ["needs-triage"], ~U[2026-10-16 09:00:00Z]), ticket("2", ["needs-triage"], nil)]

    assert line(status: :available, truncated?: true, tickets: tickets) == "TRIAGE needs-triage >1h >=1 (oldest #1 3h) unknown age 1 TRUNCATED"
  end

  test "aiur status prints the TRIAGE line from the open-ticket projection" do
    snapshot = %Snapshot{status: :available, tickets: [ticket("7", ["needs-triage"], ~U[2026-10-15 09:00:00Z])]}
    parent = self()
    previous = Process.whereis(Aiur.OpenTicketSource)
    if previous, do: Process.unregister(Aiur.OpenTicketSource)

    stub =
      spawn(fn ->
        Process.register(self(), Aiur.OpenTicketSource)
        send(parent, :stub_ready)

        receive do
          {:"$gen_call", from, :snapshot} -> GenServer.reply(from, snapshot)
        end
      end)

    on_exit(fn ->
      Process.exit(stub, :kill)
      if previous && Process.alive?(previous), do: Process.register(previous, Aiur.OpenTicketSource)
    end)

    assert_receive :stub_ready, 1_000
    assert capture_io(&CLI.print_wake_status/0) =~ ~r/TRIAGE needs-triage >1h 1 \(oldest #7 \d+h\)/
  end

  test "a closed ticket still labelled needs-triage produces no finding" do
    # The open-ticket projection lists open issues only; the cached label set also holds closed ones.
    snapshot = %{tickets: [%{number: 1277, labels: ["needs-triage"], created_at: ~U[2026-10-01 09:00:00Z]}], open_tickets: %Snapshot{status: :available}}

    refute Enum.any?(Checks.all(snapshot, @now), &(&1.kind == "stale_needs_triage"))
  end

  test "no finding while the projection is not available" do
    open = [ticket("1", ["needs-triage"], ~U[2026-10-16 09:00:00Z])]

    for status <- [:stale, :unavailable, :unsupported] do
      assert [] = Checks.all(%{open_tickets: %Snapshot{status: status, tickets: open}}, @now)
    end
  end

  test "a growing stale-triage backlog wakes the Executor for each new ticket" do
    parent = self()
    {:ok, tickets} = Agent.start_link(fn -> [ticket("1", ["needs-triage"], ~U[2026-10-16 09:00:00Z])] end)
    sweep = fn -> Checks.all(%{open_tickets: %Snapshot{status: :available, tickets: Agent.get(tickets, & &1)}}, @now) |> Enum.filter(&(&1.kind == "stale_needs_triage")) end

    assert {:ok, pid} = ExecutorSweep.start_link(name: nil, interval_ms: 60_000, sweep_fun: sweep, publish_fun: &send(parent, {:finding, &1}))
    assert_receive {:finding, %{kind: "stale_needs_triage", ticket: "1"}}, 1_000

    Agent.update(tickets, &[ticket("2", ["needs-triage"], ~U[2026-10-16 10:00:00Z]) | &1])
    send(pid, :sweep)
    assert_receive {:finding, %{kind: "stale_needs_triage", ticket: "2"}}, 1_000
    refute_receive {:finding, %{ticket: "1"}}, 50

    GenServer.stop(pid)
    Agent.stop(tickets)
  end
end
