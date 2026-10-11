defmodule Aiur.PrMerge.Rules do
  @moduledoc false
  alias Aiur.PrMerge.Client

  @spec read(function(), String.t(), String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def read(api, repo, base, user) do
    path = "repos/#{repo}/rules/branches/#{URI.encode(base, &URI.char_unreserved?/1)}"

    with {:ok, rules} when is_list(rules) <- api.("get", path, nil),
         true <- not Enum.any?(rules, &(&1["type"] == "workflows")) or {:error, "required workflow rules are not supported; wait for GitHub CI"},
         {:ok, protection} <- protection(api, repo, base),
         {:ok, repository} <- api.("get", "repos/#{repo}", nil),
         {:ok, bypass} <- bypass(api, repo, rules, protection, repository, user) do
      required = for %{"type" => "required_status_checks", "parameters" => %{"required_status_checks" => checks}} <- rules, check <- checks, do: check_name(check)
      legacy_checks = get_in(protection, ["required_status_checks", "checks"])
      legacy = if legacy_checks, do: Enum.map(legacy_checks, &check_name/1), else: get_in(protection, ["required_status_checks", "contexts"]) || []
      {:ok, %{required: Enum.uniq(required ++ legacy), bypass: bypass}}
    else
      {:error, _reason} = error -> error
      _ -> {:error, "invalid branch rules observation"}
    end
  end

  defp check_name(%{"context" => name, "integration_id" => id}) when is_integer(id) and id > 0, do: "#{name} (app #{id})"
  defp check_name(%{"context" => name, "app_id" => id}) when is_integer(id) and id > 0, do: "#{name} (app #{id})"
  defp check_name(%{"context" => name}), do: name

  defp protection(api, repo, base) do
    case api.("get", "repos/#{repo}/branches/#{URI.encode(base, &URI.char_unreserved?/1)}/protection", nil) do
      {:error, "GitHub 404:" <> _} -> {:ok, %{}}
      result -> result
    end
  end

  defp bypass(api, repo, rules, protection, repository, user) do
    relevant = Enum.filter(rules, &(&1["type"] in ["pull_request", "required_status_checks"]))
    ids = Enum.uniq(Enum.map(relevant, & &1["ruleset_id"]))
    admin = get_in(repository, ["permissions", "admin"]) == true

    with {:ok, sets} <- rulesets(api, repo, ids),
         {:ok, teams} <- teams(api, sets) do
      allowed = sets != [] and Enum.all?(sets, &actor_allowed?(&1, user, admin, teams))
      {:ok, allowed and legacy_bypass?(protection, user, admin)}
    end
  end

  defp rulesets(api, repo, ids) do
    Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, acc} ->
      case api.("get", "repos/#{repo}/rulesets/#{id}", nil) do
        {:ok, set} when is_map(set) -> {:cont, {:ok, [set | acc]}}
        {:error, _} = error -> {:halt, error}
        _ -> {:halt, {:error, "invalid ruleset"}}
      end
    end)
  end

  defp teams(api, sets) do
    actors = Enum.flat_map(sets, &(&1["bypass_actors"] || []))

    if Enum.any?(actors, &(&1["actor_type"] == "Team")) do
      with {:ok, teams} <- Client.pages(api, "user/teams"), do: {:ok, Enum.map(teams, & &1["id"])}
    else
      {:ok, []}
    end
  end

  defp actor_allowed?(set, user, admin, teams) do
    Enum.any?(set["bypass_actors"] || [], fn actor ->
      actor["bypass_mode"] in ["always", "pull_request"] and
        ((actor["actor_type"] == "User" and actor["actor_id"] == user["id"]) or
           (actor["actor_type"] == "RepositoryRole" and actor["actor_id"] == 5 and admin) or
           (actor["actor_type"] == "Team" and actor["actor_id"] in teams))
    end)
  end

  defp legacy_bypass?(protection, user, admin) do
    review = protection["required_pull_request_reviews"]
    users = get_in(review || %{}, ["bypass_pull_request_allowances", "users"]) || []
    review == nil or Enum.any?(users, &(&1["id"] == user["id"])) or (admin and get_in(protection, ["enforce_admins", "enabled"]) == false)
  end
end
