defmodule Aiur.TestTicketScope do
  @moduledoc """
  Limits issue discovery for the development `aiurdev --test` harness.

  The launcher validates the pinned ticket file before exporting the internal
  scope. An absent scope leaves ordinary runs unchanged; a malformed one must
  fail closed before startup cleanup can touch a workspace.
  """

  @env "AIUR_DEV_TEST_TICKET_IDS"

  @spec validate!() :: :ok
  def validate! do
    _ids = allowed_ids!()
    :ok
  end

  @spec filter_result(term()) :: term()
  def filter_result({:ok, issues}) when is_list(issues), do: {:ok, filter_issues(issues)}
  def filter_result({:ok, issues, cache}) when is_list(issues), do: {:ok, filter_issues(issues), cache}
  def filter_result(other), do: other

  @spec filter_issues(list()) :: list()
  def filter_issues(issues) when is_list(issues) do
    case allowed_ids!() do
      :all -> issues
      allowed -> Enum.filter(issues, &MapSet.member?(allowed, identifier(&1)))
    end
  end

  @spec allowed_identifier?(String.t() | nil) :: boolean()
  def allowed_identifier?(identifier) when is_binary(identifier) do
    case allowed_ids!() do
      :all -> true
      allowed -> MapSet.member?(allowed, identifier)
    end
  end

  def allowed_identifier?(_identifier), do: allowed_ids!() == :all

  @spec with_write_scope(map(), (-> term())) :: term()
  def with_write_scope(request, fun), do: with(:ok <- allow_write?(request), do: fun.())

  @doc "Whether an outgoing GitHub state mutation is inside the active test scope."
  @spec allow_write?(map()) :: :ok | {:error, {:outside_test_ticket_scope, String.t()}}
  def allow_write?(%{method: method, url: url} = request)
      when method in [:post, :patch, :put, :delete] and is_binary(url) do
    case System.get_env(@env) do
      nil ->
        :ok

      ids when is_binary(ids) and ids != "" ->
        allow_scoped_write(request, resource_number(url))

      _invalid_scope ->
        {:error, {:outside_test_ticket_scope, "unknown"}}
    end
  end

  def allow_write?(%{method: method, url: url}) when method in [:post, :patch, :put, :delete] and is_binary(url),
    do: {:error, {:outside_test_ticket_scope, "unknown"}}

  def allow_write?(_request), do: :ok

  defp allow_scoped_write(%{method: :post, url: url}, _resource) do
    if installation_token_request?(url), do: :ok, else: deny_write("unknown")
  end

  defp allow_scoped_write(_request, {:ok, :issue, number}) do
    if allowed_identifier?(number), do: :ok, else: deny_write(number)
  end

  defp allow_scoped_write(_request, _resource), do: deny_write("unknown")

  defp deny_write(identifier), do: {:error, {:outside_test_ticket_scope, identifier}}

  defp installation_token_request?(url) do
    Regex.match?(~r{\Ahttps://api\.github\.com/app/installations/[1-9][0-9]*/access_tokens\z}, url)
  end

  defp resource_number(url) do
    case Regex.run(~r{/repos/[^/]+/[^/]+/(issues|pulls)(?:/([^/?]+))?(?:/|\?|$)}, url, capture: :all_but_first) do
      ["issues", number] when is_binary(number) -> if(Regex.match?(~r/\A[1-9][0-9]*\z/, number), do: {:ok, :issue, number}, else: :invalid)
      ["pulls", _number] -> :invalid
      ["issues"] -> :invalid
      _ -> :invalid
    end
  end

  defp identifier(%{identifier: identifier}) when is_binary(identifier), do: identifier
  defp identifier(%{identifier: identifier}) when is_integer(identifier), do: Integer.to_string(identifier)
  defp identifier(_issue), do: nil

  defp allowed_ids! do
    case System.get_env(@env) do
      nil ->
        :all

      ids when is_binary(ids) ->
        if Regex.match?(~r/\A[1-9][0-9]*(?:,[1-9][0-9]*)*\z/, ids) do
          ids |> String.split(",") |> MapSet.new()
        else
          raise ArgumentError, "invalid #{@env}; expected comma-separated positive ticket IDs"
        end
    end
  end
end
