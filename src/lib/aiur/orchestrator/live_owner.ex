defmodule Aiur.Orchestrator.LiveOwner do
  @moduledoc false

  alias Aiur.Issue

  @spec owns?(map(), String.t()) :: boolean()
  def owns?(running, issue_id) when is_map(running) do
    Map.has_key?(running, issue_id) or
      Enum.any?(running, fn {_key, entry} ->
        match?(%Issue{id: ^issue_id}, Map.get(entry, :issue))
      end)
  end
end
