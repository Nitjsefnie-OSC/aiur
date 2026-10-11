defmodule Aiur.MainWatch.GitHubTest do
  use Aiur.TestSupport
  alias Aiur.MainWatch.GitHub

  setup do
    write_workflow_file!(Aiur.Workflow.workflow_file_path(), tracker_kind: "github", tracker_repo: "owner/repo")
    :ok
  end

  test "chronological watched observations exclude website failures, pending and cancelled commits" do
    request = fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") ->
          ok(Enum.map(~w(new pending cancelled old), &%{"sha" => &1}))

        String.contains?(url, "/actions/runs?") ->
          sha = URI.decode_query(URI.parse(url).query)["head_sha"]

          {id, status, conclusion} =
            case sha do
              "new" -> {4, "completed", "success"}
              "pending" -> {3, "in_progress", nil}
              "cancelled" -> {2, "completed", "cancelled"}
              "old" -> {1, "completed", "success"}
            end

          ok(%{"workflow_runs" => [run(id, sha, "ci", status, conclusion), run(id + 10, sha, "website", "completed", "failure")]})

        String.contains?(url, "/check-runs?") ->
          ok(%{"check_runs" => [check(1, 1, "success"), check(2, 2, "failure")]})

        String.ends_with?(url, "/status") ->
          ok(%{"statuses" => [%{"state" => "error", "context" => "external"}]})

        true ->
          flunk("unexpected request #{url}")
      end
    end

    assert {:ok, result} = GitHub.poll("main", ["ci"], request_fun: request, actions_write: false)
    assert Enum.map(result.observations, & &1.sha) == ["old", "new"]
    assert Enum.map(result.runs, & &1.sha) == ["new", "pending", "cancelled", "old"]
    assert Enum.map(result.observations, & &1.checks) == List.duplicate([%{name: "test", conclusion: "success"}], 2)
    assert Enum.all?(result.observations, &(&1.digest.checks == []))
    assert hd(result.observations).completed_at == DateTime.to_unix(~U[2026-10-10 00:00:00Z], :millisecond)
  end

  test "missing configured workflows stay pending while older complete SHA remains observable" do
    request = fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") ->
          ok([%{"sha" => "new"}, %{"sha" => "old"}])

        String.contains?(url, "/actions/runs?") ->
          sha = URI.decode_query(URI.parse(url).query)["head_sha"]
          runs = [run(1, sha, "ci", "completed", "success")]
          runs = if sha == "old", do: runs ++ [run(2, sha, "deploy", "completed", "success")], else: runs
          ok(%{"workflow_runs" => runs})

        String.contains?(url, "/check-runs?") ->
          ok(%{"check_runs" => [check(1, 1, "success"), check(2, 2, "success")]})

        String.ends_with?(url, "/status") ->
          ok(%{"statuses" => []})

        true ->
          flunk("unexpected request #{url}")
      end
    end

    assert {:ok, result} = GitHub.poll("main", ["ci", "deploy"], request_fun: request, actions_write: false)
    assert Enum.map(result.observations, & &1.sha) == ["old"]
  end

  test "watched failure retains annotations while website failures stay excluded" do
    request = fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") -> ok([%{"sha" => "red-filtered"}])
        String.contains?(url, "/actions/runs?") -> ok(%{"workflow_runs" => [run(1, "red-filtered", "ci", "completed", "failure"), run(2, "red-filtered", "website", "completed", "failure")]})
        String.contains?(url, "/commits/red-filtered/check-runs?") -> ok(%{"check_runs" => [check(1, 1, "failure"), check(2, 2, "failure")]})
        String.ends_with?(url, "/status") -> ok(%{"statuses" => []})
        String.contains?(url, "/check-runs/1/annotations?") -> ok([%{"title" => "aiur-test-failure", "message" => "new-failure :: ExampleTest :: regression", "annotation_level" => "failure"}])
        String.contains?(url, "/contents/") -> ok(%{"encoding" => "base64", "content" => ""})
        String.contains?(url, "/issues?") -> ok([])
        true -> flunk("unwatched annotations must not be read: #{url}")
      end
    end

    assert {:ok, %{observations: [observation]}} = GitHub.poll("main", ["ci"], request_fun: request, actions_write: false)
    assert [%{id: 1, name: "test", tests: [%{identity: "ExampleTest :: regression", classification: :new_failure}]}] = observation.digest.checks
    assert observation.digest.tests == [%{identity: "ExampleTest :: regression", classification: :new_failure}]
    refute observation.digest.flake_only
  end

  test "fail-fast cancelled children remain real failure evidence for completed failed workflow" do
    request = fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") -> ok([%{"sha" => "fail-fast-red"}])
        String.contains?(url, "/actions/runs?") -> ok(%{"workflow_runs" => [run(1, "fail-fast-red", "ci", "completed", "failure")]})
        String.contains?(url, "/check-runs?") -> ok(%{"check_runs" => [check(1, 1, "failure"), Map.put(check(2, 1, "cancelled"), "name", "cancelled partition")]})
        String.ends_with?(url, "/status") -> ok(%{"statuses" => []})
        String.contains?(url, "/check-runs/1/annotations?") -> ok([%{"title" => "aiur-test-failure", "message" => "new-failure :: ExampleTest :: fail fast", "annotation_level" => "failure"}])
        String.contains?(url, "/check-runs/2/annotations?") -> ok([])
        String.contains?(url, "/contents/") -> ok(%{"encoding" => "base64", "content" => ""})
        String.contains?(url, "/issues?") -> ok([])
        true -> flunk("unexpected request: #{url}")
      end
    end

    assert {:ok, %{observations: [observation]}} = GitHub.poll("main", ["ci"], request_fun: request, actions_write: false)
    assert observation.failed_workflow
    assert Enum.sort(Enum.map(observation.checks, & &1.conclusion)) == ["cancelled", "failure"]
    assert Enum.map(observation.digest.checks, & &1.id) == [1, 2]
    assert observation.digest.tests == [%{identity: "ExampleTest :: fail fast", classification: :new_failure}]
    refute observation.digest.flake_only
  end

  test "newest successful check attempt supersedes a cancelled older check in its suite" do
    request = fn %{url: url} ->
      cond do
        String.contains?(url, "/commits?") -> ok([%{"sha" => "rerun-success"}])
        String.contains?(url, "/actions/runs?") -> ok(%{"workflow_runs" => [run(1, "rerun-success", "ci", "completed", "success")]})
        String.contains?(url, "/check-runs?") -> ok(%{"check_runs" => [check(1, 1, "cancelled"), check(2, 1, "success")]})
        String.ends_with?(url, "/status") -> ok(%{"statuses" => []})
        true -> flunk("superseded cancelled check must not buy annotations: #{url}")
      end
    end

    assert {:ok, %{observations: [observation]}} = GitHub.poll("main", ["ci"], request_fun: request, actions_write: false)
    assert observation.checks == [%{name: "test", conclusion: "success"}]
    assert observation.digest.checks == []
  end

  test "pagination and provider errors cannot produce a partial green verdict" do
    for response <- [{:ok, %{status: 200, body: %{"workflow_runs" => []}, headers: [{"link", "<https://api.github.com/next>; rel=\"next\""}]}}, {:ok, %{status: 403, body: %{}}}] do
      request = fn %{url: url} -> if String.contains?(url, "/commits?"), do: ok([%{"sha" => "abc"}]), else: response end
      assert {:error, _} = GitHub.poll("main", [], request_fun: request, actions_write: false)
    end
  end

  test "rerun posts to Actions and never claims success on rejection" do
    parent = self()

    request = fn request ->
      send(parent, request)
      {:ok, %{status: 201, body: %{}}}
    end

    assert :ok = GitHub.rerun(42, request_fun: request)
    assert_received %{method: :post, url: "https://api.github.com/repos/owner/repo/actions/runs/42/rerun", caller: "main_watch_canary", body: %{}}
    assert {:error, {:github, :http, %{status: 403}}} = GitHub.rerun(42, request_fun: fn _ -> {:ok, %{status: 403, body: %{}}} end)
  end

  test "probe checks actual App installation permissions and fails closed on PAT and errors" do
    vars = ~w(GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY GITHUB_APP_PRIVATE_KEY_PATH)
    previous = Map.new(vars, &{&1, System.get_env(&1)})
    on_exit(fn -> Enum.each(previous, fn {key, value} -> if value, do: System.put_env(key, value), else: System.delete_env(key) end) end)
    Enum.each(vars, &System.delete_env/1)
    refute GitHub.actions_write?(request_fun: fn _ -> flunk("PAT must not be probed as App") end)
    key = JOSE.JWK.generate_key({:rsa, 2048})
    {_, pem} = JOSE.JWK.to_pem(key)
    System.put_env(%{"GITHUB_APP_ID" => "123", "GITHUB_APP_INSTALLATION_ID" => "456", "GITHUB_APP_PRIVATE_KEY" => pem})

    for permission <- ["read", "write", nil] do
      request = fn %{token: jwt, url: url, caller: "main_watch_permissions", credential_pinned?: true} ->
        assert url == "https://api.github.com/app/installations/456"
        assert JOSE.JWT.verify_strict(key, ["RS256"], jwt) |> elem(0)
        ok(%{"permissions" => %{"actions" => permission}})
      end

      assert GitHub.actions_write?(request_fun: request) == (permission == "write")
    end

    refute GitHub.actions_write?(request_fun: fn _ -> {:error, :closed} end)
    refute GitHub.actions_write?(request_fun: fn _ -> ok(%{"permissions" => "unknown"}) end)
  end

  defp run(id, sha, name, status, conclusion),
    do: %{
      "id" => id,
      "head_sha" => sha,
      "head_branch" => "main",
      "event" => "push",
      "name" => name,
      "status" => status,
      "conclusion" => conclusion,
      "check_suite_id" => if(name == "ci", do: 1, else: 2),
      "updated_at" => "2026-10-10T00:00:00Z",
      "html_url" => "https://example.test/#{id}"
    }

  defp check(id, suite, conclusion), do: %{"id" => id, "name" => "test", "check_suite" => %{"id" => suite}, "app" => %{"slug" => "github-actions"}, "status" => "completed", "conclusion" => conclusion}
  defp ok(body), do: {:ok, %{status: 200, body: body, headers: []}}
end
