defmodule Aiur.ExecutorSweep.TriageBacklog do
  @moduledoc """
  Open `needs-triage` tickets older than an hour. Nothing dispatches them, so
  `aiur status` prints the count and the sweep wakes the Executor per newly
  stale ticket (#4521).
  """

  alias Aiur.OpenTicketSource.Snapshot

  @stale_ms 60 * 60_000

  @doc "Whether a ticket with these labels, created at `created_at`, has needed triage for over an hour."
  @spec stale?([String.t()], DateTime.t() | nil, DateTime.t()) :: boolean()
  def stale?(labels, %DateTime{} = created_at, %DateTime{} = now), do: "needs-triage" in labels and DateTime.diff(now, created_at, :millisecond) > @stale_ms
  def stale?(_labels, _created_at, _now), do: false

  @doc "`TRIAGE needs-triage >1h N (oldest #id <age>)` from the open-ticket projection."
  @spec status_line(Snapshot.t(), DateTime.t()) :: String.t()
  def status_line(%Snapshot{status: status}, _now) when status in [:unavailable, :unsupported], do: "TRIAGE unavailable (the open-ticket listing is not loaded)"

  def status_line(%Snapshot{} = snapshot, %DateTime{} = now) do
    stale = snapshot.tickets |> Enum.filter(&stale?(&1.labels, &1.created_at, now)) |> Enum.sort_by(& &1.created_at, DateTime)
    suffix = if snapshot.status == :stale, do: " STALE", else: ""

    case stale do
      [] -> "TRIAGE needs-triage >1h 0" <> suffix
      [oldest | _] -> "TRIAGE needs-triage >1h #{length(stale)} (oldest ##{oldest.identifier} #{hours(DateTime.diff(now, oldest.created_at))})" <> suffix
    end
  end

  @doc "Prints the status line from the live open-ticket projection."
  @spec print_status() :: :ok
  def print_status, do: IO.puts(status_line(Aiur.OpenTicketSource.snapshot(), DateTime.utc_now()))

  defp hours(seconds), do: "#{div(seconds, 3600)}h"
end
