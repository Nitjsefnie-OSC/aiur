defmodule Aiur.GitHub.PullRequestCommitCacheTest do
  use Aiur.TestSupport

  alias Aiur.GitHub.{PullRequests, ReadCache}

  setup do
    prev_token = System.get_env("GITHUB_TOKEN")
    System.put_env("GITHUB_TOKEN", "test-gh-token")
    ReadCache.reset()

    write_workflow_file!(Aiur.Workflow.workflow_file_path(),
      tracker_kind: "github",
      tracker_repo: "owner/repo"
    )

    on_exit(fn -> restore_env("GITHUB_TOKEN", prev_token) end)
    :ok
  end

  test "merged commit messages are shared by PR head and fetched again for a new head" do
    number = System.unique_integer([:positive])
    parent = self()
    requests = :atomics.new(1, [])

    first_fetch = fn request ->
      :atomics.add(requests, 1, 1)
      send(parent, {:fetched, request.url})
      Process.sleep(20)
      {:ok, %{status: 200, body: [%{"commit" => %{"message" => "Refs #5605"}}], headers: []}}
    end

    concurrent =
      for _ <- 1..2 do
        Task.async(fn -> PullRequests.fetch_pull_request_commits(number, request_fun: first_fetch, head_sha: "head-one") end)
      end

    assert Enum.map(concurrent, &Task.await(&1, 1000)) == [{:ok, ["Refs #5605"]}, {:ok, ["Refs #5605"]}]
    assert :atomics.get(requests, 1) == 1
    assert_receive {:fetched, url}, 1000
    assert url =~ "/pulls/#{number}/commits"

    assert {:ok, ["Refs #5605"]} =
             PullRequests.fetch_pull_request_commits(number, request_fun: fn _ -> flunk("same head must use cached commit messages") end, head_sha: "head-one")

    assert {:ok, ["Refs #5605"]} =
             PullRequests.fetch_pull_request_commits(number, request_fun: first_fetch, head_sha: "head-two")

    assert_receive {:fetched, _url}, 1000
    assert :atomics.get(requests, 1) == 2
  end
end
