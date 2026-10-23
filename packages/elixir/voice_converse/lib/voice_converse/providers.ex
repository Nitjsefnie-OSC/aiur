defmodule VoiceConverse.Providers do
  @moduledoc """
  The provider registry and credential-presence resolver for a VoiceConverse session.

  This module never opens a connection or receives a secret. It only asks the configured
  credentials port to probe whether a provider is available.
  """

  alias VoiceConverse.Config

  @credential_env %{
    anthropic: "ANTHROPIC_API_KEY",
    elevenlabs: "ELEVENLABS_API_KEY",
    gemini: "GEMINI_API_KEY",
    openai: "OPENAI_API_KEY"
  }
  @part_credentials %{
    elevenlabs_stt: :elevenlabs,
    elevenlabs_tts: :elevenlabs,
    openai_stt: :openai,
    openai_tts: :openai
  }
  @registry [
    {:openai_live, VoiceConverse.Providers.OpenAILive,
     %{
       id: :openai_live,
       family: :speech_to_speech,
       label: "OpenAI Live",
       modes: [:voice],
       needs: [:openai],
       privacy: %{audio_stored_by_provider: true, deletable?: false},
       price_hint: "about USD 0.05/min"
     }},
    {:openai_realtime, VoiceConverse.Providers.OpenAIRealtime,
     %{
       id: :openai_realtime,
       family: :speech_to_speech,
       label: "OpenAI Realtime",
       modes: [:voice],
       needs: [:openai],
       privacy: %{audio_stored_by_provider: true, deletable?: false},
       price_hint: "token-priced"
     }},
    {:gemini_live, VoiceConverse.Providers.GeminiLive,
     %{
       id: :gemini_live,
       family: :speech_to_speech,
       label: "Gemini Live",
       modes: [:voice],
       needs: [:gemini],
       privacy: %{audio_stored_by_provider: true, deletable?: false},
       price_hint: "about USD 0.023/min"
     }},
    {:elevenlabs_agents, VoiceConverse.Providers.ElevenLabsAgents,
     %{
       id: :elevenlabs_agents,
       family: :hosted_agent,
       label: "ElevenLabs Agents",
       modes: [:voice, :text],
       needs: [:elevenlabs],
       privacy: %{audio_stored_by_provider: true, deletable?: true},
       price_hint: "about USD 0.08/min"
     }},
    {:cascade, nil,
     %{
       id: :cascade,
       family: :cascade,
       label: "Cascade",
       modes: [:voice, :text],
       needs: [],
       privacy: %{audio_stored_by_provider: false, deletable?: false},
       price_hint: "depends on selected parts"
     }},
    {:text_only, nil,
     %{
       id: :text_only,
       family: :cascade,
       label: "Text only",
       modes: [:text],
       needs: [],
       privacy: %{audio_stored_by_provider: false, deletable?: false},
       price_hint: "model-token-priced"
     }},
    {:codex_realtime, VoiceConverse.Providers.CodexRealtime,
     %{
       id: :codex_realtime,
       family: :agent_native,
       label: "Codex Realtime",
       modes: [:voice, :text],
       needs: [:openai],
       privacy: %{audio_stored_by_provider: false, deletable?: false},
       price_hint: "experimental"
     }}
  ]

  @spec default_preference() :: [atom()]
  def default_preference, do: Config.default_provider_preference()

  @spec credential_env(atom()) :: String.t() | nil
  def credential_env(provider), do: Map.get(@credential_env, provider)

  @spec options(Config.t()) :: [map()]
  def options(%Config{} = config), do: Enum.map(@registry, &option(&1, config))

  @spec resolve(Config.t()) ::
          {:ok, map(), skipped: [{atom(), term()}]} | {:error, :no_usable_option, [{atom(), term()}]}
  def resolve(%Config{} = config) do
    {result, skipped} = resolve_preference(config.providers.preference, config, [])

    case result do
      {:ok, option} -> {:ok, option, skipped: Enum.reverse(skipped)}
      :none -> fallback_to_text_only(config, Enum.reverse(skipped))
    end
  end

  defp resolve_preference([], _config, skipped), do: {:none, skipped}

  defp resolve_preference([id | ids], config, skipped) do
    case option_by_id(id, config) do
      nil ->
        resolve_preference(ids, config, [{id, :unknown_option} | skipped])

      %{modes: modes} = option ->
        resolve_option(id, ids, option, modes, config, skipped)
    end
  end

  defp resolve_option(id, ids, option, modes, config, skipped) do
    cond do
      config.providers.mode not in modes ->
        resolve_preference(ids, config, [{id, {:mode_unsupported, config.providers.mode}} | skipped])

      option.status == :ready ->
        {{:ok, option}, skipped}

      match?({:missing_credential, _provider}, option.reason) and config.providers.on_missing_credential == :refuse ->
        {:none, [{id, option.reason} | skipped]}

      true ->
        resolve_preference(ids, config, [{id, option.reason} | skipped])
    end
  end

  defp fallback_to_text_only(
         %Config{providers: %{on_missing_credential: :text_only, preference: preference}} = config,
         skipped
       ) do
    if :text_only in preference do
      {:error, :no_usable_option, skipped}
    else
      case option_by_id(:text_only, config) do
        %{status: :ready} = option -> {:ok, option, skipped: skipped}
        %{reason: reason} -> {:error, :no_usable_option, skipped ++ [{:text_only, reason}]}
      end
    end
  end

  defp fallback_to_text_only(_config, skipped), do: {:error, :no_usable_option, skipped}

  defp option_by_id(id, config) do
    case Enum.find(@registry, fn {option_id, _module, _descriptor} -> option_id == id end) do
      nil -> nil
      entry -> option(entry, config)
    end
  end

  defp option({id, module, fallback}, config) do
    descriptor = descriptor(id, module, fallback, config)

    case configuration_availability(id, module, config) do
      :ok -> option_after_configuration(module, descriptor, config)
      {:error, reason} -> Map.merge(descriptor, %{status: :unsupported, missing: [], reason: reason})
    end
  end

  defp option_after_configuration(module, descriptor, config) do
    case adapter_availability(module) do
      :ok -> credential_option(descriptor, config)
      {:error, reason} -> Map.merge(descriptor, %{status: :unsupported, missing: [], reason: reason})
    end
  end

  defp descriptor(:cascade, _module, fallback, config), do: cascade_descriptor(fallback, config, :cascade)
  defp descriptor(:text_only, _module, fallback, config), do: cascade_descriptor(fallback, config, :text_only)

  defp descriptor(_id, module, fallback, _config) do
    if is_atom(module) and Code.ensure_loaded?(module) and function_exported?(module, :descriptor, 0) do
      Map.merge(fallback, module.descriptor())
    else
      fallback
    end
  end

  defp cascade_descriptor(fallback, config, kind) do
    cascade = config.providers.cascade
    parts = %{stt: cascade.stt, llm: cascade.llm, tts: cascade.tts}

    case kind do
      :cascade ->
        Map.merge(fallback, %{needs: cascade_needs(cascade), parts: parts, client_parts: client_parts(cascade)})

      :text_only ->
        text_tts = if :browser_tts in cascade.tts, do: :browser_tts, else: :none

        Map.merge(fallback, %{
          needs: llm_needs(cascade.llm),
          parts: %{stt: :text_in, llm: cascade.llm, tts: text_tts},
          client_parts: [:text_in] ++ if(text_tts == :browser_tts, do: [:browser_tts], else: [])
        })
    end
  end

  defp configuration_availability(:codex_realtime, _module, %Config{providers: %{features: %{codex_realtime: true}}}),
    do: :ok

  defp configuration_availability(:codex_realtime, _module, _config), do: {:error, :feature_unavailable}

  defp configuration_availability(id, _module, %Config{providers: %{cascade: %{llm: nil}}})
       when id in [:cascade, :text_only],
       do: {:error, :cascade_not_configured}

  defp configuration_availability(_id, _module, _config), do: :ok

  defp adapter_availability(nil), do: :ok

  defp adapter_availability(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :descriptor, 0),
      do: :ok,
      else: {:error, :adapter_missing}
  end

  defp credential_option(descriptor, config) do
    case missing_credentials(descriptor.needs, config) do
      [] ->
        Map.merge(descriptor, %{status: :ready, missing: [], reason: :ready})

      missing ->
        Map.merge(descriptor, %{status: :needs_credential, missing: missing, reason: {:missing_credential, hd(missing)}})
    end
  end

  defp missing_credentials(needs, %Config{credentials: credentials}) do
    Enum.reject(needs, fn provider ->
      credentials.fetch(provider, :probe) == {:ok, :present}
    end)
  end

  defp cascade_needs(cascade) do
    (llm_needs(cascade.llm) ++ Enum.flat_map(cascade.stt ++ cascade.tts, &List.wrap(Map.get(@part_credentials, &1))))
    |> Enum.uniq()
  end

  defp llm_needs(llm) when is_binary(llm) do
    case String.split(llm, ":", parts: 2) do
      ["anthropic", _model] -> [:anthropic]
      ["gemini", _model] -> [:gemini]
      ["openai", _model] -> [:openai]
      _ -> []
    end
  end

  defp llm_needs(_llm), do: []

  defp client_parts(cascade) do
    Enum.filter(cascade.stt ++ cascade.tts, &(&1 in [:browser_stt, :browser_tts, :text_in]))
  end
end
