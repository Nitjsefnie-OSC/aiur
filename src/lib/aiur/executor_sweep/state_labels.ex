defmodule Aiur.ExecutorSweep.StateLabels do
  @moduledoc """
  One summary finding for open tickets without exactly one agent state label
  (#5119). Parked, triage, human-owned and epic tickets are skipped: nothing
  dispatches them, so their missing state label is expected.
  """

  alias Aiur.GitHub.Config
  alias Aiur.GitHub.Labels

  @spec raw_labels(map()) :: [String.t()]
  def raw_labels(ticket) do
    ticket
    |> Map.get(:labels, Map.get(ticket, "labels", []))
    |> Enum.map(fn label ->
      if is_map(label), do: Map.get(label, :name, Map.get(label, "name", "")), else: label
    end)
    |> Enum.map(&to_string/1)
  end

  @doc "Takes tickets with raw labels and their configured prefix; returns zero or one finding."
  @spec findings([map()]) :: [map()]
  def findings(tickets), do: findings(tickets, Config.label_prefix())

  @spec findings([map()], String.t()) :: [map()]
  def findings(tickets, prefix) when is_list(tickets) and is_binary(prefix) do
    state_labels = Labels.state_labels(prefix)

    case for(
           ticket <- tickets,
           labels = ticket.labels,
           not excluded?(labels, prefix),
           states = matching_states(labels, state_labels, prefix),
           length(states) != 1,
           not foreign_only?(labels, states, prefix),
           do: {ticket, states}
         ) do
      [] ->
        []

      invalid ->
        {oldest, states} = Enum.min_by(invalid, &age_key/1)
        count = length(invalid)

        [
          %{
            kind: "invalid_state_labels",
            priority: 9,
            age_ms: 0,
            action: "Review the open tickets and leave exactly one agent state label on each.",
            message: "#{count} open ticket(s) have an invalid count of agent state labels (oldest ticket ##{oldest.number || "?"}, #{length(states)} labels).",
            ticket: oldest.number,
            ticket_count: count,
            state_labels: states
          }
        ]
    end
  end

  defp matching_states(labels, state_labels, prefix) do
    labels
    |> Enum.filter(&(&1 in state_labels))
    |> Enum.map(&String.replace_prefix(&1, prefix <> ":", ""))
  end

  defp excluded?(labels, prefix) do
    Enum.any?(labels, fn label ->
      suffix = String.replace_prefix(label, prefix <> ":", "")
      suffix in ["parked", "needs-triage", "human:todo"] or String.downcase(suffix) == "epic" or String.starts_with?(String.downcase(suffix), "epic:")
    end)
  end

  defp foreign_only?(labels, [], prefix) do
    state_suffixes = Enum.map(Labels.state_labels(prefix), &String.replace_prefix(&1, prefix <> ":", ""))

    Enum.any?(labels, fn label ->
      case String.split(label, ":", parts: 2) do
        [other_prefix, state] when other_prefix != prefix -> state in state_suffixes
        _other -> false
      end
    end)
  end

  defp foreign_only?(_labels, _states, _prefix), do: false

  # Oldest by creation time; tickets without one sort after, by number.
  defp age_key({ticket, _states}) do
    case ticket.created_at && DateTime.from_iso8601(to_string(ticket.created_at)) do
      {:ok, created_at, _offset} -> {0, DateTime.to_unix(created_at, :millisecond), ticket.number || 0}
      _ -> {1, 0, ticket.number || 0}
    end
  end
end
