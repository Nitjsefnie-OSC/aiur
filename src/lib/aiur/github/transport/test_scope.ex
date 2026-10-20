defmodule Aiur.GitHub.Transport.TestScope do
  @moduledoc false

  alias Aiur.GitHub.QueueCost
  alias Aiur.GitHub.CredentialSelector
  alias Aiur.GitHub.Transport.AuthDiagnostic

  @spec run(map(), (map() -> term())) :: term()
  def run(request, execute) when is_function(execute, 1) do
    selector_opts = Application.get_env(:aiur, :github_credential_selector_options, [])

    Aiur.TestTicketScope.with_write_scope(request, fn ->
      case request do
        %{token: token, credential_pinned?: true} when is_binary(token) ->
          request = request |> QueueCost.tag() |> CredentialSelector.assign(selector_opts)
          request |> execute.() |> AuthDiagnostic.annotate(request)

        %{token: token} when is_binary(token) ->
          AuthDiagnostic.run(request, execute)

        request ->
          request |> QueueCost.tag() |> execute.()
      end
    end)
  end
end
