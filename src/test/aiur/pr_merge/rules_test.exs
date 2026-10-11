defmodule Aiur.PrMerge.RulesTest do
  use ExUnit.Case, async: true
  alias Aiur.PrMerge.Rules

  defp api(actors, protection \\ %{}) do
    fn
      "get", "repos/o/r/rules/branches/integration", _ ->
        {:ok, [%{"type" => "required_status_checks", "ruleset_id" => 1, "parameters" => %{"required_status_checks" => [%{"context" => "lint", "integration_id" => 123}]}}]}

      "get", "repos/o/r/branches/integration/protection", _ ->
        {:ok, protection}

      "get", "repos/o/r", _ ->
        {:ok, %{"permissions" => %{"admin" => true}}}

      "get", "repos/o/r/rulesets/1", _ ->
        {:ok, %{"bypass_actors" => actors}}
    end
  end

  test "ruleset bypass must match the human ID or its repository role" do
    user = %{"id" => 7}
    assert {:ok, %{required: ["lint (app 123)"], bypass: true}} = Rules.read(api([%{"actor_type" => "User", "actor_id" => 7, "bypass_mode" => "pull_request"}]), "o/r", "integration", user)
    assert {:ok, %{bypass: false}} = Rules.read(api([%{"actor_type" => "User", "actor_id" => 8, "bypass_mode" => "always"}]), "o/r", "integration", user)
    assert {:ok, %{bypass: true}} = Rules.read(api([%{"actor_type" => "RepositoryRole", "actor_id" => 5, "bypass_mode" => "always"}]), "o/r", "integration", user)
  end

  test "team bypass requires actual operator membership" do
    base = api([%{"actor_type" => "Team", "actor_id" => 99, "bypass_mode" => "always"}])

    member = fn
      "get", "user/teams?per_page=100&page=1", _ -> {:ok, [%{"id" => 99}]}
      method, path, body -> base.(method, path, body)
    end

    assert {:ok, %{bypass: true}} = Rules.read(member, "o/r", "integration", %{"id" => 7})

    absent = fn
      "get", "user/teams?per_page=100&page=1", _ -> {:ok, []}
      method, path, body -> base.(method, path, body)
    end

    assert {:ok, %{bypass: false}} = Rules.read(absent, "o/r", "integration", %{"id" => 7})
  end

  test "legacy admin enforcement prevents claiming ruleset bypass for approval" do
    protection = %{"required_pull_request_reviews" => %{}, "enforce_admins" => %{"enabled" => true}, "required_status_checks" => %{"checks" => [%{"context" => "legacy", "app_id" => 456}]}}

    assert {:ok, %{bypass: false, required: ["lint (app 123)", "legacy (app 456)"]}} =
             Rules.read(api([%{"actor_type" => "RepositoryRole", "actor_id" => 5, "bypass_mode" => "always"}], protection), "o/r", "integration", %{"id" => 7})
  end
end
