defmodule Aiur.ExecutorSweep.CacheFreshnessTest do
  use ExUnit.Case, async: true

  alias Aiur.ExecutorSweep.{CacheFreshness, SnapshotCache}
  alias Aiur.GitHub.ResourceStore
  alias Aiur.LandingWatch.MergeGroupRunFetcher

  @now ~U[2026-10-15 18:20:00Z]
  @max_age_ms 5 * 60_000

  defp group(id), do: %{id: id, name: "run #{id}", state: "in_progress", started_at: ~U[2026-10-15 02:00:00Z], head_branch: "gh-readonly-queue/main/pr-7-abc"}

  defp stale_groups(groups, evidence) do
    snapshot = %{merge_groups: groups, github_cache_ages: %{merge_group_runs: Map.new(groups, &{&1.id, 60_000}), merge_group_evidence: evidence}}
    CacheFreshness.stale_merge_groups(snapshot, @now, 15, @max_age_ms)
  end

  defp put_page(repo, id, data, age_ms) do
    key = ResourceStore.key(:landing_merge_group_runs, "aiur-team", repo, id)
    :ok = ResourceStore.put_resource(key, data, source: :fetch)
    [{^key, entry}] = :ets.lookup(Aiur.GitHub.ResourceStore.Table, key)
    :ets.insert(Aiur.GitHub.ResourceStore.Table, {key, Map.put(entry, :fetched_at_ms, System.system_time(:millisecond) - age_ms)})
  end

  test "a cached in_progress run that LandingWatch now lists as completed produces no finding" do
    repo = "aiur-freshness-#{System.unique_integer([:positive])}"
    for status <- ["queued", "in_progress", "waiting", "requested"], do: put_page(repo, "main:#{status}:0:age-index", [], 60_000)
    put_page(repo, "main:in_progress:0:age-index", [%{"id" => 900}], 60_000)
    put_page(repo, "main:completed:0:age-index", [%{"id" => 39_610_162_849}], 60_000)
    put_page(repo, "main:refs", ["refs/heads/gh-readonly-queue/main/pr-7-abc"], 60_000)

    evidence = SnapshotCache.github_cache_ages("aiur-team", repo).merge_group_evidence

    assert [] = stale_groups([group(39_610_162_849)], evidence)
    assert [%{kind: "stale_merge_group", verification: "verified"}] = stale_groups([group(900)], evidence)
  end

  test "a run missing from every fresh active listing produces no finding" do
    evidence = %{runs: %{}, active_listing_age_ms: 60_000, refs: nil}
    assert [] = stale_groups([group(41)], evidence)

    # A stale listing proves nothing, so the run is still reported (unverified by its own age).
    assert [_] = stale_groups([group(41)], %{evidence | active_listing_age_ms: @max_age_ms + 1})
  end

  test "the landing watch's queue-ref read is what the sweep sees" do
    repo = "aiur-freshness-#{System.unique_integer([:positive])}"
    body = [%{"ref" => "refs/heads/gh-readonly-queue/main/pr-7-abc"}]
    request = fn %{url: url} -> if url =~ "matching-refs", do: {:ok, %{status: 200, body: body}} end

    assert {:ok, _} = MergeGroupRunFetcher.queue_group_refs("aiur-team", repo, "main", "token", request_fun: request)
    assert %{refs: ["refs/heads/gh-readonly-queue/main/pr-7-abc"]} = SnapshotCache.github_cache_ages("aiur-team", repo).merge_group_evidence.refs
  end

  # Guard: passes before #5738 too; it pins that the new filters never hide a run GitHub still runs.
  test "a live in_progress run older than the threshold is still reported" do
    evidence = %{runs: %{42 => %{status: "in_progress", age_ms: 30_000}}, active_listing_age_ms: 60_000, refs: %{refs: ["refs/heads/gh-readonly-queue/main/pr-7-abc"], age_ms: 30_000}}
    assert [%{kind: "stale_merge_group", merge_group: "run 42"}] = stale_groups([group(42)], evidence)
  end

  test "a run whose queue ref is gone produces no finding" do
    evidence = %{runs: %{43 => %{status: "in_progress", age_ms: 30_000}}, active_listing_age_ms: 60_000, refs: %{refs: ["refs/heads/gh-readonly-queue/main/pr-8-def"], age_ms: 30_000}}
    assert [] = stale_groups([group(43)], evidence)
    assert [_] = stale_groups([group(43)], put_in(evidence, [:refs, :age_ms], @max_age_ms + 1))
  end
end
