defmodule AiurWeb.HostAllowlist do
  @moduledoc "Reject requests whose Host header is outside the configured dashboard hosts."

  @behaviour Plug

  import Plug.Conn
  require Logger

  @loopback_hosts ["localhost", "127.0.0.1", "[::1]", "::1"]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    allowed_hosts = AiurWeb.EndpointConfig.get(:allowed_hosts, []) |> Enum.map(&normalize_host/1)
    observed_host = host_name(conn.host)
    log_first_observed_host(observed_host)

    if is_binary(observed_host) and normalize_host(observed_host) in allowed_hosts do
      conn
    else
      conn
      |> send_resp(:forbidden, "Forbidden")
      |> halt()
    end
  end

  @doc false
  @spec allowed_hosts(String.t() | nil, [String.t()] | nil) :: [String.t()]
  def allowed_hosts(public_url, configured_hosts \\ nil) do
    hosts = configured_hosts || [public_url_host(public_url) | @loopback_hosts]
    hosts |> Enum.reject(&is_nil/1) |> Enum.map(&normalize_host/1) |> Enum.uniq()
  end

  @doc false
  @spec origins(String.t() | nil) :: [String.t()]
  def origins(public_url) do
    public_origin =
      public_url
      |> url_parts()
      |> then(fn
        nil -> nil
        uri -> "#{uri.scheme}://#{uri.host}" <> port_suffix(uri)
      end)

    [public_origin, "//localhost", "//127.0.0.1", "//[::1]"]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp public_url_host(nil), do: nil
  defp public_url_host(url), do: url |> url_parts() |> then(&if(&1, do: &1.host))

  defp url_parts(url) when is_binary(url) do
    uri = URI.parse(url)
    if uri.scheme in ["http", "https"] and is_binary(uri.host), do: uri, else: nil
  end

  defp url_parts(_), do: nil

  defp port_suffix(%URI{port: nil}), do: ""
  defp port_suffix(%URI{scheme: "http", port: 80}), do: ""
  defp port_suffix(%URI{scheme: "https", port: 443}), do: ""
  defp port_suffix(%URI{port: port}), do: ":#{port}"

  defp host_name(nil), do: nil
  defp host_name(value), do: value |> String.trim_leading("[") |> String.trim_trailing("]") |> String.trim_trailing(".")

  defp normalize_host(host) when is_binary(host), do: String.downcase(String.trim_trailing(host, "."))
  defp normalize_host(host), do: host

  defp log_first_observed_host(host) do
    key = {__MODULE__, AiurWeb.Endpoint}

    unless :persistent_term.get(key, nil) do
      :global.trans({key, self()}, fn -> log_first_observed_host_once(key, host) end)
    end
  end

  defp log_first_observed_host_once(key, host) do
    if is_nil(:persistent_term.get(key, nil)) do
      Logger.info("Aiur dashboard first observed Host header: #{inspect(host)}")
      :persistent_term.put(key, true)
    end
  end
end
