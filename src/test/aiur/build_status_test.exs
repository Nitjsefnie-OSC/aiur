defmodule Aiur.BuildStatusTest do
  use ExUnit.Case, async: true

  alias Aiur.BuildStatus
  alias Aiur.RecentMerge

  @now ~U[2026-10-22 18:13:00Z]

  test "counts cached merges newer than the stamped build and names the newest PR" do
    merges = [merge(901, "main-new"), merge(900, "main-old")]

    status = BuildStatus.present(%{source_sha: "built-sha", built_at: "2026-10-22T05:08:00Z"}, merges, @now)

    assert status == %{sha: "built-sha", built_at: ~U[2026-10-22 05:08:00Z], age: "13h", behind: 2, newest_pr: 901}
    assert BuildStatus.render(status) == "BUILD built-sha built 13h ago · 2 commits behind origin/main (#901)"
  end

  test "unknown or unmatched main never claims the build is current" do
    for merges <- [:unknown, []] do
      status = BuildStatus.present(%{source_sha: "built-sha"}, merges, @now)
      assert status.behind == nil
      assert BuildStatus.render(status) == "BUILD built-sha built unknown ago · unknown commits behind origin/main"
    end
  end

  test "a build at the cached main head has zero commits behind" do
    status = BuildStatus.present(%{source_sha: "main-new", built_at: "2026-10-22T18:12:00Z"}, [merge(901, "main-new")], @now)

    assert status.behind == 0
    assert BuildStatus.render(status) == "BUILD main-new built 1m ago · 0 commits behind origin/main"
  end

  defp merge(number, sha) do
    %RecentMerge{
      schema_version: 1,
      id: "aiur-team/aiur##{number}",
      repository: "aiur-team/aiur",
      number: number,
      url: "https://github.com/aiur-team/aiur/pull/#{number}",
      merged_at: @now,
      observation_source: :github_events,
      backfilled?: true,
      live_observed?: false,
      first_observed_at: @now,
      last_observed_at: @now,
      reconciled_ticket_ids: [],
      merge_commit_sha: sha,
      content_hash: "hash"
    }
  end
end
