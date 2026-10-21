defmodule Aiur.RunTelemetry.Cohort do
  @moduledoc "Bounded cohort values preserved by capture and reduction."
  @spec work_kind([String.t()], String.t() | nil) :: String.t()
  def work_kind(labels, title) do
    cond do
      "build-order" in labels or Enum.any?(labels, &(String.starts_with?(&1, "build-lane:") or String.starts_with?(&1, "feature:"))) -> "feature"
      Enum.any?(labels, &(contains_any?(String.downcase(&1), ["flake", "test"]) or String.starts_with?(&1, "main-fix"))) or title_matches?(title, ~r/\b(test|flake|ci|quarantine)\b/i) -> "test_ci"
      Enum.any?(labels, &contains_any?(String.downcase(&1), ["tooling", "chore"])) or title_matches?(title, ~r/\b(tooling|chore|dependency|deps)\b/i) -> "tooling"
      true -> "other"
    end
  end

  defp title_matches?(title, pattern), do: is_binary(title) and Regex.match?(pattern, title)
  defp contains_any?(value, needles), do: Enum.any?(needles, &String.contains?(value, &1))

  @spec event_fields(map()) :: map()
  def event_fields(attributes) do
    Map.new([:backend, :model, :effort, :feature, :epic, :tags, :work_kind, :blockers, :start_mode], &{&1, attributes[Atom.to_string(&1)]})
  end

  @spec bounded_strings(list()) :: [String.t()]
  def bounded_strings(values) do
    values |> Enum.filter(&(is_binary(&1) or is_integer(&1))) |> Enum.take(20) |> Enum.map(&String.slice(to_string(&1), 0, 64))
  end

  @spec normalize_metadata_value(atom(), term()) :: term()
  def normalize_metadata_value(:tags, value) when is_map(value), do: bounded_tags(value)
  def normalize_metadata_value(key, value) when key in [:tags, :blockers] and is_list(value), do: bounded_strings(value)
  def normalize_metadata_value(:optimistic_blockers, value) when is_list(value), do: Enum.filter(value, &is_binary/1)
  def normalize_metadata_value(_key, nil), do: nil
  def normalize_metadata_value(_key, value), do: normalize_metadata_value(value)

  defp normalize_metadata_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_metadata_value(value) when is_boolean(value), do: value
  defp normalize_metadata_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_metadata_value(value) when is_binary(value) or is_number(value), do: value
  defp normalize_metadata_value(_value), do: "unknown"

  defp bounded_tags(tags) do
    tags
    |> Enum.filter(fn {key, value} -> is_binary(key) and (is_binary(value) or is_number(value) or is_boolean(value)) end)
    |> Enum.take(20)
    |> Map.new(fn {key, value} -> {String.slice(key, 0, 64), normalize_metadata_value(value)} end)
  end
end
