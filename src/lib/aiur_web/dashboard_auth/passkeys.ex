defmodule AiurWeb.DashboardAuth.Passkeys do
  @moduledoc false

  alias Aiur.Config
  alias Aiur.Config.Paths
  alias AiurWeb.DashboardAuth.ChallengeStore

  @file_name "dashboard-passkeys.json"

  @spec enabled?() :: boolean()
  def enabled?, do: Config.settings!().dashboard_auth.passkeys
  @spec available?() :: boolean()
  def available?, do: enabled?() and match?({:ok, [_ | _]}, credentials())

  @spec origin_and_rp_id() :: {:ok, String.t(), String.t()} | {:error, :public_https_url_required}
  def origin_and_rp_id do
    with url when is_binary(url) <- Config.settings!().server.public_url,
         %URI{scheme: "https", host: host} = uri <- URI.parse(url) do
      origin = "https://#{host}" <> if(uri.port && uri.port != 443, do: ":#{uri.port}", else: "")
      {:ok, origin, host}
    else
      _ -> {:error, :public_https_url_required}
    end
  end

  @spec registration_challenge() :: {:ok, Wax.Challenge.t()} | {:error, atom()}
  def registration_challenge do
    with true <- enabled?(),
         {:ok, origin, host} <- origin_and_rp_id() do
      {:ok, Wax.new_registration_challenge(attestation: "none", origin: origin, rp_id: host, user_verification: "required")}
    else
      _ -> {:error, :passkeys_unavailable}
    end
  end

  @spec authentication_challenge() :: {:ok, Wax.Challenge.t(), list()} | {:error, atom()}
  def authentication_challenge do
    with true <- enabled?(),
         {:ok, origin, host} <- origin_and_rp_id(),
         {:ok, credentials} <- credentials() do
      if credentials == [] do
        {:error, :no_passkeys}
      else
        wax_credentials = Enum.map(credentials, &{&1.id, &1.key})
        {:ok, Wax.new_authentication_challenge(allow_credentials: wax_credentials, origin: origin, rp_id: host, user_verification: "required"), credentials}
      end
    else
      _ -> {:error, :passkeys_unavailable}
    end
  end

  @spec put_challenge(Wax.Challenge.t()) :: {:ok, String.t()}
  def put_challenge(challenge), do: ChallengeStore.put(challenge)
  @spec take_challenge(term()) :: {:ok, Wax.Challenge.t()} | {:error, atom()}
  def take_challenge(id) when is_binary(id), do: ChallengeStore.take(id)
  def take_challenge(_), do: {:error, :challenge_missing_or_replayed}

  @spec register(Wax.Challenge.t(), binary(), binary(), term(), String.t()) :: :ok | {:error, atom()}
  def register(challenge, attestation, client_data_json, label, owner_email) do
    with %Wax.Challenge{} <- challenge,
         {:ok, attestation} <- decode64(attestation),
         {:ok, client_data_json} <- decode64(client_data_json),
         {:ok, {auth_data, _attestation}} <- Wax.register(attestation, client_data_json, challenge),
         credential <- auth_data.attested_credential_data,
         id <- Base.url_encode64(credential.credential_id, padding: false),
         {:ok, existing} <- credentials(),
         false <- Enum.any?(existing, &(&1.id == id)),
         key <- credential.credential_public_key,
         :ok <- store_credentials(existing ++ [%{id: id, key: key, sign_count: auth_data.sign_count, label: safe_label(label), email: String.downcase(owner_email)}]) do
      :ok
    else
      _ -> {:error, :invalid_registration}
    end
  end

  @spec authenticate(Wax.Challenge.t(), map()) :: {:ok, map()} | {:error, atom()}
  def authenticate(challenge, assertion) do
    with %Wax.Challenge{} <- challenge,
         {:ok, id_raw} <- decode64(assertion["rawId"] || assertion["id"]),
         id <- Base.url_encode64(id_raw, padding: false),
         credential when not is_nil(credential) <- Enum.find(credentials!(), &(&1.id == id)),
         response when is_map(response) <- assertion["response"],
         {:ok, client_data_json} <- decode64(response["clientDataJSON"]),
         {:ok, auth_data} <- Wax.authenticate(id, decode64!(response["authenticatorData"]), decode64!(response["signature"]), client_data_json, challenge),
         true <- sign_count_valid?(credential.sign_count, auth_data.sign_count),
         :ok <- update_sign_count(credential, auth_data.sign_count) do
      {:ok, credential}
    else
      _ -> {:error, :invalid_assertion}
    end
  end

  @spec allowed_user?(map()) :: boolean()
  def allowed_user?(%{email: email}) do
    allowed = Config.settings!().dashboard_auth.google.allowed_emails
    is_binary(email) and String.downcase(email) in Enum.map(allowed, &String.downcase/1)
  end

  @doc false
  @spec sign_count_valid?(non_neg_integer(), non_neg_integer()) :: boolean()
  def sign_count_valid?(0, 0), do: true
  def sign_count_valid?(previous, current), do: current >= previous

  defp update_sign_count(old, count) do
    updated = Enum.map(credentials!(), fn credential -> if credential.id == old.id, do: %{credential | sign_count: count}, else: credential end)
    store_credentials(updated)
  end

  defp credentials, do: with({:ok, path} <- file_path(), do: read_credentials(path))

  defp credentials! do
    case credentials() do
      {:ok, values} -> values
      _ -> []
    end
  end

  defp read_credentials(path) do
    case File.read(path) do
      {:ok, json} ->
        with {:ok, records} when is_list(records) <- Jason.decode(json), do: {:ok, Enum.map(records, &decode_record/1)}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, :invalid_credentials_file}
  end

  defp store_credentials(records) do
    with {:ok, path} <- file_path(),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.chmod(Path.dirname(path), 0o700),
         :ok <- atomic_write(path, Jason.encode!(Enum.map(records, &encode_record/1))),
         do: File.chmod(path, 0o600)
  end

  defp atomic_write(path, data) do
    temp = path <> ".tmp-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

    with {:ok, file} <- File.open(temp, [:write, :binary, :exclusive], 0o600),
         :ok <- IO.binwrite(file, data),
         :ok <- File.close(file),
         :ok <- File.rename(temp, path) do
      :ok
    else
      error ->
        _ = File.rm(temp)
        error
    end
  end

  defp file_path do
    case Application.get_env(:aiur, :dashboard_passkeys_path) do
      path when is_binary(path) ->
        {:ok, path}

      _ ->
        case Paths.decision_state_dir() do
          {:ok, directory} -> {:ok, Path.join(directory, @file_name)}
          error -> error
        end
    end
  end

  defp encode_record(%{id: id, key: key, sign_count: count, label: label, email: email}) do
    %{id: id, key: Map.new(key, fn {k, v} -> {to_string(k), encode_key_value(v)} end), sign_count: count, label: label, email: email}
  end

  defp decode_record(%{"id" => id, "key" => key, "sign_count" => count, "label" => label, "email" => email}) do
    decoded_key = Map.new(key, fn {k, v} -> {String.to_integer(k), decode_key_value(v)} end)
    %{id: id, key: decoded_key, sign_count: count, label: label, email: email}
  end

  defp encode_key_value(value) when is_binary(value), do: %{"binary" => Base.encode64(value)}
  defp encode_key_value(value), do: value
  defp decode_key_value(%{"binary" => value}), do: Base.decode64!(value)
  defp decode_key_value(value), do: value

  defp decode64!(value), do: Base.url_decode64!(value, padding: false)
  defp decode64(value) when is_binary(value), do: Base.url_decode64(value, padding: false)
  defp decode64(_), do: :error
  defp safe_label(label) when is_binary(label), do: label |> String.trim() |> String.slice(0, 80)
  defp safe_label(_), do: "Passkey"
end
