defmodule VoiceConverse.Ports.Credentials do
  @moduledoc """
  Required port: provider secrets, fetched at the moment of use. The secret must never be kept
  in process state or logs.
  """

  @type purpose :: :connect | :delete | :probe | :provision | :render

  @callback fetch(provider :: atom(), purpose :: purpose()) ::
              {:ok, String.t() | :present} | {:error, :missing}
end
