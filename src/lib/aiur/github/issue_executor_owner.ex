defmodule Aiur.GitHub.IssueExecutorOwner do
  @moduledoc false

  alias Aiur.GitHub.Labels

  @spec from_labels([String.t()], String.t()) :: String.t() | nil
  def from_labels(label_names, prefix) when is_list(label_names) do
    owner_prefix = prefix |> Labels.executor_label_prefix() |> normalize_label()

    Enum.find_value(label_names, fn label ->
      normalized = normalize_label(label)
      owner = String.replace_prefix(normalized, owner_prefix, "")
      if owner != normalized and owner != "", do: owner
    end)
  end

  defp normalize_label(label) when is_binary(label), do: String.downcase(String.trim(label))
  defp normalize_label(_label), do: ""
end
