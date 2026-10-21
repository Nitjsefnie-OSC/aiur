defmodule AiurWeb.Build.TicketControl do
  @moduledoc "Truthful modal control and server-owned conversation destinations."
  alias Aiur.TrackerIdentity
  alias AiurWeb.OperatorControlCenter.UnitsControlPolicy, as: Policy

  @spec encode(map() | nil, map() | nil, boolean()) :: map()
  def encode(nil, _control, _writable), do: %{control: nil, chat: nil}

  def encode(row, control, writable) do
    affordance = Policy.affordance(row, control)
    status = if control, do: status(control)
    action = affordance.action || affordance.pending_action
    title = title(affordance, status, writable)
    %{control: %{action: action, state: if(writable, do: affordance.state, else: :disabled), title: title, status: status}, chat: chat_path(row)}
  end

  defp status(control) do
    presentation = Policy.presentation(control)
    %{label: presentation.label, tone: presentation.tone, retry: presentation.retry?}
  end

  defp title(_affordance, _status, false), do: "Dashboard is read-only"
  defp title(%{state: :disabled, reason: reason}, _status, true), do: Policy.disabled_reason(reason)
  defp title(_affordance, %{tone: tone, label: label}, true) when tone in [:pending, :error, :warning], do: label
  defp title(%{action: :resume}, _status, true), do: "Resume agent"
  defp title(_affordance, _status, true), do: "Pause agent"

  @spec chat_path(map()) :: String.t() | nil
  def chat_path(%{identity: %TrackerIdentity{owner: owner, repository: repo, identifier: id}})
      when is_binary(owner) and is_binary(repo) and is_binary(id) do
    "/chat/" <> Enum.map_join([owner, repo, id], "/", &URI.encode(&1, fn char -> URI.char_unreserved?(char) end))
  end

  def chat_path(_row), do: nil
end
