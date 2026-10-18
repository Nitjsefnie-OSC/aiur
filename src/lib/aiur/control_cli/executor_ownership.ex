defmodule Aiur.ControlCLI.ExecutorOwnership do
  @moduledoc false

  alias Aiur.{Config, GitHub.Labels, Issue, Tracker}
  alias Aiur.Orchestrator.TicketTransition
  import Aiur.ControlCLI.Protocol, only: [exit_marker: 1, guarded: 2, control_error: 1]

  @spec take([String.t()]) :: :ok
  def take(targets), do: update(targets, :add, "take")

  @spec release([String.t()]) :: :ok
  def release(targets), do: update(targets, :remove, "release")

  defp update(targets, action, verb) do
    guarded(verb, fn ->
      owner = owner()
      label = Labels.executor_label_prefix(Config.settings!().tracker.github.label_prefix) <> owner
      results = Enum.map(targets, &write_marker(&1, action, label))
      Enum.each(results, &report(&1, verb, owner))
      exit_marker(if Enum.any?(results, &match?({:error, _}, &1)), do: 1, else: 0)
    end)
  end

  defp write_marker(id, action, label) do
    case Tracker.fetch_issue_states_by_ids([to_string(id)]) do
      {:ok, [issue]} -> write_resolved_marker(issue, id, action, label)
      {:ok, []} -> {id, {:error, :issue_not_found}}
      {:error, reason} -> {id, {:error, reason}}
    end
  end

  defp write_resolved_marker(issue, id, action, label) do
    current = executor_labels(issue)
    result = replace_owner_marker(issue.identifier, current, label, action)
    {id, result}
  end

  defp replace_owner_marker(identifier, current, desired, :add) do
    case remove_other_owners(identifier, current, desired) do
      :ok -> TicketTransition.write_marker(identifier, :add, desired, writer: :executor_ownership)
      error -> error
    end
  end

  defp replace_owner_marker(identifier, current, desired, :remove) do
    if desired in current do
      TicketTransition.write_marker(identifier, :remove, desired, writer: :executor_ownership)
    else
      {:error, :not_owner}
    end
  end

  defp remove_other_owners(identifier, current, desired) do
    Enum.reduce_while(current, :ok, fn label, :ok ->
      if label == desired do
        {:cont, :ok}
      else
        remove_other_owner(identifier, label)
      end
    end)
  end

  defp remove_other_owner(identifier, label) do
    case TicketTransition.write_marker(identifier, :remove, label, writer: :executor_ownership) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  defp executor_labels(issue) do
    prefix = Labels.executor_label_prefix(Config.settings!().tracker.github.label_prefix)
    Enum.filter(Issue.label_names(issue), &String.starts_with?(String.downcase(&1), String.downcase(prefix)))
  end

  defp report({id, :ok}, "take", owner), do: IO.puts("aiur: ticket ##{id} held by #{owner}")
  defp report({id, :ok}, "release", _owner), do: IO.puts("aiur: Executor hold released for ##{id}")
  defp report({id, {:error, :not_owner}}, verb, owner), do: control_error("aiur: cannot #{verb} ##{id}; it is owned by another Executor, not #{owner}")
  defp report({id, {:error, reason}}, verb, _owner), do: control_error("aiur: could not #{verb} ##{id}: #{inspect(reason)}")

  defp owner do
    requested = System.get_env("AIUR_EXECUTOR_OWNER") || System.get_env("USER") || "executor"
    owner = requested |> String.downcase() |> String.replace(~r/[^a-z0-9-]/, "-") |> String.trim("-") |> String.slice(0, 30)
    if owner == "", do: "executor", else: owner
  end
end
