defmodule AiurWeb.Session do
  @moduledoc false
  @behaviour Plug

  @session_options [
    store: :cookie,
    key: "_aiur_key",
    signing_salt: "aiur-session",
    encryption_salt: "aiur-session-encryption",
    same_site: "Lax"
  ]

  @doc false
  @spec runtime_options() :: keyword()
  def runtime_options do
    max_age = Aiur.Config.settings!().dashboard_auth.session_max_age_days * 86_400
    Keyword.put(@session_options, :max_age, max_age)
  end

  @impl Plug
  def init(opts), do: Plug.Session.init(opts)

  @impl Plug
  def call(conn, config) do
    endpoint_config = Application.get_env(:aiur, AiurWeb.Endpoint, [])
    configured_secure? = Keyword.get(endpoint_config, :session_options, [])[:secure] == true
    secure? = configured_secure? or conn.scheme == :https

    config =
      Map.update!(config, :cookie_opts, fn cookie_opts ->
        cookie_opts
        |> Keyword.put(:secure, secure?)
        |> Keyword.put(:max_age, runtime_options()[:max_age])
      end)

    Plug.Session.call(conn, config)
  end
end
