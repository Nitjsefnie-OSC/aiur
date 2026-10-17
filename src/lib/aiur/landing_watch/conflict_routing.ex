defmodule Aiur.LandingWatch.ConflictRouting do
  @moduledoc """
  Routes an approved pull request that conflicts with its base to rebase-only rework (#4729).

  A conflicting PR can never land, and GitHub leaves a conflicting merge queue
  entry in place, so the watcher dequeues it, moves the ticket to rework, tells
  the agent to rebase only, and lifts the `agent:paused` override approved
  tickets carry so the rework can dispatch. The approval is left untouched for
  re-review to compare against.
  """

  alias Aiur.{CodeHost, Config, Tracker}

  @failure %{name: "Merge conflict with base"}

  @spec conflicting?(map()) :: boolean()
  def conflicting?(observation), do: Map.get(observation, :mergeable) == "CONFLICTING"

  @doc "Takes the PR out of the queue, then routes it through `rework` with a rebase-only follow-up."
  @spec route(map(), (map(), [map()], keyword() -> :ok | {:error, term()}), keyword()) :: :ok | {:error, term()}
  def route(observation, rework, opts) do
    with :ok <- withdraw(observation, opts) do
      rework.(observation, [@failure], Keyword.put(opts, :after_rework, &follow_up(observation, &1, opts)))
    end
  end

  defp withdraw(%{merge_queue_entry: nil, auto_merge_request: nil}, _opts), do: :ok

  defp withdraw(observation, opts) do
    case Keyword.get(opts, :withdraw_fun, &CodeHost.withdraw_landing/1).(observation.number) do
      {:ok, _actions} -> :ok
      {:error, reason, _actions} -> {:error, {:conflict_withdrawal_failed, reason}}
      {:error, reason} -> {:error, {:conflict_withdrawal_failed, reason}}
    end
  end

  defp follow_up(observation, issue, opts) do
    comment = Keyword.get(opts, :comment_fun, &Tracker.create_comment/2)
    unpause = Keyword.get(opts, :remove_label_fun, &Tracker.remove_label/2)

    with :ok <- comment.(issue, comment_body(observation)) do
      unpause.(issue, Keyword.get_lazy(opts, :pause_label, &pause_label/0))
    end
  end

  @doc false
  @spec comment_body(map()) :: String.t()
  def comment_body(observation) do
    base = Map.get(observation, :base) || "the base branch"

    """
    **Rebase only.** Approved PR ##{observation.number} conflicts with `#{base}`, so the landing watcher took it out of the merge queue and moved this ticket to rework.

    Integrate `#{base}`, resolve the conflicts, and push. Make no other change. The approval at `#{observation.head}` stays on record so re-review can compare the contribution diff.
    """
  end

  defp pause_label, do: "#{Config.settings!().tracker.github.label_prefix}:paused"
end
