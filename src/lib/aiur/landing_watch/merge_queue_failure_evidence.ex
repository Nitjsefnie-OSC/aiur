defmodule Aiur.LandingWatch.MergeQueueFailureEvidence do
  @moduledoc false

  @spec run_pr_numbers(binary() | nil, String.t()) :: [pos_integer()]
  def run_pr_numbers(branch, base) when is_binary(branch) do
    prefix = "gh-readonly-queue/#{base}/"

    if String.starts_with?(branch, prefix) do
      Regex.scan(~r/pr-(\d+)-/, branch, capture: :all_but_first) |> List.flatten() |> Enum.map(&String.to_integer/1)
    else
      []
    end
  end

  def run_pr_numbers(_, _), do: []

  @spec rebuilt_group_count([map()], map(), [pos_integer()], String.t(), integer()) :: non_neg_integer()
  def rebuilt_group_count(runs, failed_run, prs, base, since_ms) do
    failed_time = parse_time(failed_run["created_at"] || failed_run["run_started_at"])
    since_time = DateTime.from_unix!(since_ms, :millisecond)

    Enum.count(runs, fn run ->
      run["event"] == "merge_group" and run["id"] != failed_run["id"] and
        Enum.any?(run_pr_numbers(run["head_branch"], base), &(&1 in prs)) and
        DateTime.compare(parse_time(run["created_at"]), since_time) in [:eq, :gt] and
        DateTime.compare(parse_time(run["created_at"]), failed_time) != :gt
    end)
  end

  @spec test_names(String.t()) :: [String.t()]
  def test_names(log) do
    Regex.scan(~r/((?:test\/)?[\w.\/-]+_test\.exs(?::\d+)?|test [^\r\n]+)/, log, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _} -> time
      _ -> DateTime.from_unix!(0)
    end
  end

  defp parse_time(_), do: DateTime.from_unix!(0)
end
