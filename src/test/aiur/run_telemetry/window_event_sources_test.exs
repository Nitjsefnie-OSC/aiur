defmodule Aiur.RunTelemetry.WindowEventSourcesTest do
  use ExUnit.Case, async: false
  alias Aiur.RunTelemetry
  @range %{start: "2026-10-08T00:00:00Z", end: "2026-10-11T00:00:00Z"}
  @sources %{"base_branch" => "trunk", "required_workflows" => ["CI"], "incident_labels" => ["incident", "outage"]}

  test "GitHub reads carry quota attribution and requested base and dates, with independent partial results" do
    parent = self()

    request = fn req ->
      send(parent, {:request, req})

      cond do
        req.method == :get ->
          {:error, :offline}

        req.body["query"] =~ "ExperimentWindowPulls" ->
          {:ok, %{status: 200, body: %{"data" => %{"search" => %{"nodes" => [%{"number" => 42}], "pageInfo" => %{"hasNextPage" => false}, "issueCount" => 1}}}}}

        req.body["query"] =~ "ExperimentWindowIncidents" ->
          {:ok, %{status: 200, body: %{"data" => %{"search" => %{"nodes" => [], "pageInfo" => %{"hasNextPage" => false}, "issueCount" => 0}}}}}

        true ->
          key = if req.body["query"] =~ "ExperimentWindowReleases", do: "releases", else: "refs"
          {:ok, %{status: 200, body: %{"data" => %{"repository" => %{key => %{"nodes" => [], "pageInfo" => %{"hasNextPage" => false}}}}}}}
      end
    end

    {data, ["github"]} = RunTelemetry.window_event_sources("owner/repo", @sources, @range, token: "test-gh-token", request_fun: request)
    assert data["pulls"] == [%{"number" => 42}]

    for _ <- 1..5 do
      assert_receive {:request, req}, 1_000
      assert req.caller == "experiment_window_events"

      if req.method == :get do
        params = URI.decode_query(URI.parse(req.url).query)
        assert params["branch"] == nil
        assert params["created"] == @range.start <> ".." <> @range.end
      else
        if req.body["query"] =~ "ExperimentWindowPulls", do: assert(req.body["variables"]["query"] =~ "base:trunk merged:2026-10-08T00:00:00Z..2026-10-11T00:00:00Z")
      end
    end
  end

  test "page limit returns retained rows and explicitly incomplete coverage" do
    request = fn req ->
      if req.method == :get do
        {:ok, %{status: 200, body: %{"workflow_runs" => [%{"id" => 1}], "total_count" => 2000}}}
      else
        {:error, :offline}
      end
    end

    {data, ["github"]} = RunTelemetry.window_event_sources("owner/repo", @sources, @range, token: "test-gh-token", request_fun: request)
    assert length(data["runs"]) == 10
    assert data["runs_partial"]
    assert data["jobs_partial"]
    assert data["jobs"] == []
  end

  test "job details are sampled to twenty runs and sampling marks jobs partial" do
    request = fn req ->
      cond do
        req.method == :get and req.url =~ "/actions/runs/" ->
          run_id = req.url |> URI.parse() |> Map.fetch!(:path) |> String.split("/") |> Enum.at(-2) |> String.to_integer()
          {:ok, %{status: 200, body: %{"jobs" => [%{"id" => run_id, "name" => "test"}]}}}

        req.method == :get ->
          page = req.url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("page") |> String.to_integer()
          runs = Enum.map(1..100, &%{"id" => (page - 1) * 100 + &1})
          {:ok, %{status: 200, body: %{"workflow_runs" => runs, "total_count" => 1_001}}}

        true ->
          key =
            cond do
              req.body["query"] =~ "ExperimentWindowPulls" -> "search"
              req.body["query"] =~ "ExperimentWindowIncidents" -> "search"
              req.body["query"] =~ "ExperimentWindowReleases" -> "releases"
              true -> "refs"
            end

          value = if key == "search", do: %{"nodes" => [], "pageInfo" => %{"hasNextPage" => false}, "issueCount" => 0}, else: %{"nodes" => [], "pageInfo" => %{"hasNextPage" => false}}
          {:ok, %{status: 200, body: %{"data" => %{"repository" => %{key => value}, "search" => value}}}}
      end
    end

    {data, missing} = RunTelemetry.window_event_sources("owner/repo", @sources, @range, token: "test-gh-token", request_fun: request)
    assert "github" in missing
    assert length(data["runs"]) == 1_000
    assert data["jobs_partial"]
    assert length(data["jobs"]) == 20
  end
end
