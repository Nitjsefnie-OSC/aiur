defmodule VoiceConverse.Provider.ElevenLabsAgents.HTTP do
  @moduledoc false

  @spec get(String.t(), keyword()) :: {:ok, non_neg_integer(), binary()} | {:error, term()}
  def get(url, opts) do
    :inets.start()

    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.map(fn {name, value} -> {String.to_charlist(name), String.to_charlist(value)} end)

    timeout = Keyword.get(opts, :receive_timeout, 5_000)

    case :httpc.request(:get, {String.to_charlist(url), headers}, [connect_timeout: timeout, timeout: timeout],
           body_format: :binary
         ) do
      {:ok, {{_version, status, _reason}, _headers, body}} -> {:ok, status, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
