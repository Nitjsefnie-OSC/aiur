defmodule AiurWeb.Session do
  @moduledoc false
  @behaviour Plug

  @impl Plug
  def init(opts), do: Plug.Session.init(opts)

  @impl Plug
  def call(conn, config) do
    configured_secure? = AiurWeb.EndpointConfig.get(:session_options, [])[:secure] == true
    secure? = configured_secure? or conn.scheme == :https
    config = Map.update!(config, :cookie_opts, &Keyword.put(&1, :secure, secure?))
    Plug.Session.call(conn, config)
  end
end
