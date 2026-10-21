defmodule Aiur.Events.GithubWebhook.Identity do
  @moduledoc """
  Resolves a delivery to the ticket identifier the fleet keys on. See "Ticket
  identity" on `Aiur.Events.GithubWebhook.Normalizer`.
  """

  alias Aiur.RecentMerge.ClosingReferences
  alias Aiur.TicketBranch

  @closing_keyword ~r/\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)\b/i

  @spec pull_request_identity(map(), keyword()) :: {:ok, String.t(), integer()} | {:drop, term()} | {:error, term()}
  def pull_request_identity(payload, opts \\ []) do
    pr = Map.get(payload, "pull_request")
    pr_number = if is_map(pr), do: Map.get(pr, "number")

    if is_map(pr) and is_integer(pr_number) do
      commit_ticket = if Keyword.get(opts, :allow_commit_messages, false), do: List.first(linked_ticket_identifiers(pr))

      case ticket_from_head_ref(pr) || ticket_from_pr_body(Map.get(pr, "body")) || commit_ticket do
        nil -> {:drop, {:unresolved_ticket, "pull_request", pr_number}}
        ticket -> {:ok, ticket, pr_number}
      end
    else
      {:error, {:malformed_payload, "pull_request"}}
    end
  end

  @spec ticket_from_head_ref(map()) :: String.t() | nil
  def ticket_from_head_ref(pr) do
    case get_in(pr, ["head", "ref"]) do
      ref when is_binary(ref) -> TicketBranch.ticket_id_from_ref("refs/heads/" <> ref)
      _other -> nil
    end
  end

  # An `issue_comment` delivery on a pull request carries the PR body as
  # `issue.body` but no head ref. Every Aiur PR description opens with a
  # closing keyword, so that keyword is the ticket mapping for this one case.
  @spec ticket_from_pr_body(term()) :: String.t() | nil
  def ticket_from_pr_body(body) when is_binary(body) do
    case Regex.run(@closing_keyword, body) do
      [_match, number] -> number
      _other -> nil
    end
  end

  def ticket_from_pr_body(_body), do: nil

  @doc "Returns closing-keyword ticket ids in an arbitrary commit message."
  @spec ticket_from_commit_message(term()) :: String.t() | nil
  def ticket_from_commit_message(message) when is_binary(message) do
    case Regex.run(@closing_keyword, message) do
      [_match, number] -> number
      _other -> nil
    end
  end

  def ticket_from_commit_message(_message), do: nil

  @doc "Returns ticket ids explicitly linked by the body or commit messages."
  @spec linked_ticket_identifiers(map()) :: [String.t()]
  def linked_ticket_identifiers(pr) do
    repository = get_in(pr, ["base", "repo", "full_name"])
    body = Map.get(pr, "body")
    body_ids = ClosingReferences.linked_identifiers_in_text(body, repository)

    commit_ids =
      pr
      |> Map.get("commit_messages", [])
      |> Enum.flat_map(fn message ->
        ClosingReferences.linked_identifiers_in_text(message, repository) ++
          List.wrap(ticket_from_commit_message(message))
      end)

    Enum.uniq(body_ids ++ commit_ids)
  end

  @spec ticket_identifier(term()) :: String.t() | nil
  def ticket_identifier(number) when is_integer(number) and number > 0, do: Integer.to_string(number)

  def ticket_identifier(number) when is_binary(number) do
    case Integer.parse(number) do
      {parsed, ""} when parsed > 0 -> Integer.to_string(parsed)
      _other -> nil
    end
  end

  def ticket_identifier(_number), do: nil
end
