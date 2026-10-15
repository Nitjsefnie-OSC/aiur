defmodule Aiur.ExecutorSweep.Checks do
  @moduledoc """
  Builds prioritized Executor sweep findings from already-observed daemon and
  GitHub snapshot data. This module performs no I/O.
  """

  @type finding :: %{kind: String.t(), priority: pos_integer(), age_ms: non_neg_integer(), action: String.t(), message: String.t()}

  @doc "Returns unreviewed human-review PR findings, oldest first."
  @spec unreviewed_prs(map(), DateTime.t(), pos_integer()) :: [finding()]
  def unreviewed_prs(snapshot, %DateTime{} = now, threshold_minutes) when is_integer(threshold_minutes) and threshold_minutes > 0 do
    snapshot
    |> Map.get(:pull_requests, [])
    |> Enum.flat_map(&unreviewed_pr_finding(&1, snapshot, now, threshold_minutes))
    |> Enum.sort_by(&{-&1.age_ms, &1.message})
  end

  defp unreviewed_pr_finding(pr, snapshot, now, threshold_minutes) when is_map(pr) do
    with false <- value(pr, :draft, false),
         "open" <- value(pr, :state, "open"),
         number when is_integer(number) <- value(pr, :issue_number, nil),
         true <- human_review_ticket?(snapshot, number),
         sha when is_binary(sha) and sha != "" <- value(pr, :head_sha, nil),
         reviewed when reviewed != sha <- value(pr, :reviewed_head_sha, nil),
         %DateTime{} = ready_at <- value(pr, :ready_at, nil),
         age_ms when age_ms > threshold_minutes * 60_000 <- DateTime.diff(now, ready_at, :millisecond) do
      [
        %{
          kind: "unreviewed_human_review_pr",
          priority: 1,
          pull_request: value(pr, :number, nil),
          issue_number: number,
          head_sha: sha,
          age_ms: age_ms,
          action: "Review the current PR head or move its ticket out of agent:human-review.",
          message: "PR ##{value(pr, :number, "?")} has waited #{duration(age_ms)} for review at its current head."
        }
      ]
    else
      _not_due -> []
    end
  end

  defp unreviewed_pr_finding(_pr, _snapshot, _now, _threshold_minutes), do: []

  defp human_review_ticket?(snapshot, number) do
    snapshot
    |> Map.get(:tickets, [])
    |> Enum.any?(fn ticket ->
      value(ticket, :number, nil) == number and "human-review" in labels(ticket)
    end)
  end

  defp labels(ticket) do
    ticket
    |> value(:labels, [])
    |> Enum.map(fn label ->
      if is_map(label), do: value(label, :name, ""), else: label
    end)
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim_leading(&1, "agent:"))
  end

  defp value(map, key, default) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp duration(ms) do
    total_minutes = div(ms, 60_000)
    hours = div(total_minutes, 60)
    minutes = rem(total_minutes, 60)
    if hours > 0, do: "#{hours}h #{minutes}m", else: "#{minutes}m"
  end
end
