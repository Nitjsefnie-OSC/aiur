defmodule Aiur.BuildStatus do
  @moduledoc """Projects the running release stamp against cached repository merges."""

  alias Aiur.RecentMerge

  @spec current(keyword()) :: map()
  def current(opts \\ []) do
    release_dir = Keyword.get(opts, :release_dir, System.get_env("AIUR_RELEASE_DIR"))
    stamp = read_stamp(release_dir)
    merges = Keyword.get_lazy(opts, :merges, &cached_merges/0)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    present(stamp, merges, now)
  end

  @doc false
  @spec present(map(), term(), DateTime.t()) :: map()
  def present(stamp, merges, %DateTime{} = now) do
    sha = valid_sha(Map.get(stamp, :source_sha))
    built_at = parse_built_at(Map.get(stamp, :built_at))
    behind = behind_count(sha, merges)

    %{
      sha: if(sha, do: String.slice(sha, 0, 12), else: "unknown"),
      built_at: built_at,
      age: if(built_at, do: age_label(DateTime.diff(now, built_at, :second)), else: "unknown"),
      behind: behind.count,
      newest_pr: behind.newest_pr
    }
  end

  @spec render(map()) :: String.t()
  def render(%{sha: sha, age: age, behind: behind, newest_pr: newest_pr}) do
    behind_text = if is_integer(behind), do: "#{behind} commits behind origin/main", else: "unknown commits behind origin/main"
    pr_text = if is_integer(newest_pr), do: " (##{newest_pr})", else: ""
    "BUILD #{sha} built #{age} ago · #{behind_text}#{pr_text}"
  end

  defp read_stamp(release_dir) when is_binary(release_dir) and release_dir != "" do
    case File.read(Path.join(release_dir, "AIUR_BUILD_STAMP")) do
      {:ok, contents} -> parse_stamp(contents)
      _ -> %{}
    end
  end

  defp read_stamp(_), do: %{}

  defp parse_stamp(contents) do
    contents
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case String.split(line, "=", parts: 2) do
        ["source_sha", value] -> [source_sha: value]
        ["built_at", value] -> [built_at: value]
        _ -> []
      end
    end)
    |> Map.new()
  end

  defp cached_merges do
    case Aiur.RecentMergeStore.snapshot() do
      %{merges: merges} when is_list(merges) -> merges
      _ -> :unknown
    end
  rescue
    _ -> :unknown
  catch
    :exit, _ -> :unknown
  end

  defp behind_count(sha, [%RecentMerge{} | _] = merges) when is_binary(sha) do
    commits = Enum.map(merges, & &1.merge_commit_sha)

    case Enum.find_index(commits, &(&1 == sha)) do
      nil -> %{count: nil, newest_pr: nil}
      index when index > 0 -> %{count: index, newest_pr: merged_pr_number(hd(merges))}
      _found -> %{count: 0, newest_pr: nil}
    end
  end

  defp behind_count(_sha, _merges), do: %{count: nil, newest_pr: nil}

  defp merged_pr_number(%RecentMerge{number: number}), do: number
  defp merged_pr_number(%{number: number}) when is_integer(number), do: number
  defp merged_pr_number(_), do: nil

  defp valid_sha(sha) when is_binary(sha) do
    if Regex.match?(~r/\A[0-9a-fA-F]{7,40}\z/, sha), do: String.downcase(sha), else: nil
  end

  defp valid_sha(_), do: nil

  defp parse_built_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_built_at(_), do: nil

  defp age_label(seconds) when seconds < 60, do: "#{max(seconds, 0)}s"
  defp age_label(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp age_label(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp age_label(seconds), do: "#{div(seconds, 86_400)}d"
end
