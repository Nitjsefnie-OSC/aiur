defmodule VoiceConverse.Provider.ElevenLabsAgentsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias VoiceConverse.Events
  alias VoiceConverse.Provider.ElevenLabsAgents
  alias VoiceConverse.Testing.StaticCredentials

  @signed_url "wss://signed.example/conversation?token=never-log-this"

  defmodule Transport do
    @key {__MODULE__, :observer}

    def configure(observer, connect_result \\ {:ok, :fake_socket}, send_result \\ {:ok, :fake_socket}),
      do: :persistent_term.put(@key, {observer, connect_result, send_result})

    def connect(url, headers) do
      send(observer(), {:transport, :connect, url, headers})
      connect_result()
    end

    def send_text(socket, text) do
      send(observer(), {:transport, :send, text})

      case send_result() do
        {:ok, _socket} -> {:ok, socket}
        {:error, _reason} = error -> error
      end
    end

    def close(socket) do
      send(observer(), {:transport, :close, socket})
      :ok
    end

    defp observer, do: :persistent_term.get(@key) |> elem(0)
    defp connect_result, do: :persistent_term.get(@key) |> elem(1)
    defp send_result, do: :persistent_term.get(@key) |> elem(2)
  end

  setup do
    StaticCredentials.put(%{elevenlabs: "xi-test-secret"})
    Transport.configure(self())
    on_exit(fn -> StaticCredentials.put(%{}) end)
    :ok
  end

  test "fetches a signed URL with the key header and connects to it" do
    {:ok, _provider} = ElevenLabsAgents.open(spec())

    assert_receive {:http, url, headers}
    assert url =~ "agent_id=agent-1"
    assert {"xi-api-key", "xi-test-secret"} in headers
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()
  end

  test "the signed URL and key are never retained or emitted" do
    assert capture_log(fn ->
             {:ok, provider} = ElevenLabsAgents.open(spec())
             assert_receive {:http, _url, _headers}
             assert_receive {:transport, :connect, @signed_url, []}
             assert_initiation_frame()
             refute inspect(:sys.get_state(provider)) =~ @signed_url
             refute inspect(:sys.get_state(provider)) =~ "xi-test-secret"
           end) =~ ""
  end

  test "a connection failure never returns the signed URL in its error" do
    Transport.configure(self(), {:error, {:unsafe, @signed_url}})

    log =
      capture_log(fn ->
        {:ok, provider} = ElevenLabsAgents.open(spec())
        assert_receive {:http, _url, _headers}
        assert_receive {:transport, :connect, @signed_url, []}
        assert_receive {:voice_conversation, ^provider, %Events.Error{} = error}
        refute error.message =~ @signed_url
      end)

    refute log =~ @signed_url
  end

  test "an initiation-send failure closes the connection it just opened" do
    Transport.configure(self(), {:ok, :fake_socket}, {:error, :send_failed})

    {:ok, provider} = ElevenLabsAgents.open(spec())

    assert_receive {:http, _url, _headers}
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()
    assert_receive {:voice_conversation, ^provider, %Events.Error{code: :provider_unavailable}}
    assert_receive {:transport, :close, :fake_socket}
  end

  test "the initiation frame carries prompt, first message, and voice overrides" do
    {:ok, _provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    frame = assert_initiation_frame()

    assert frame["conversation_config_override"]["agent"]["prompt"]["prompt"] == "system\n\ncontext"
    assert frame["conversation_config_override"]["agent"]["first_message"] == "Hello"
    assert frame["conversation_config_override"]["tts"]["voice_id"] == "voice-1"
  end

  test "audio before metadata is buffered then flushed in order" do
    {:ok, provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    :ok = ElevenLabsAgents.push_audio(provider, "first")
    :ok = ElevenLabsAgents.push_audio(provider, "second")
    :ok = ElevenLabsAgents.push_audio(provider, "third")
    refute_receive {:transport, :send, _text}

    metadata(provider)

    assert audio_frame() == "first"
    assert audio_frame() == "second"
    assert audio_frame() == "third"
  end

  test "ping is answered with pong" do
    {:ok, provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    send(provider, {:elevenlabs_agents_transport, :text, Jason.encode!(%{type: "ping", event_id: 7})})

    assert_receive {:transport, :send, pong}
    assert Jason.decode!(pong) == %{"event_id" => 7, "type" => "pong"}
  end

  test "401, 429, and unknown signed URL responses use distinct provider codes" do
    for {status, code} <- [{401, :provider_auth}, {429, :provider_quota}, {418, :provider_error}] do
      {:ok, provider} = ElevenLabsAgents.open(spec(http: http_response(status, "{}")))

      assert_receive {:voice_conversation, ^provider, %Events.Error{code: ^code}}
      assert_receive {:voice_conversation, ^provider, %Events.Closed{reason: ^code}}
      refute_receive {:transport, :connect, _url, _headers}
    end
  end

  test "a missing key does not make an HTTP request" do
    StaticCredentials.put(%{})

    assert {:error, %Events.Error{code: :provider_auth}} = ElevenLabsAgents.open(spec())
    refute_receive {:http, _url, _headers}
    refute_receive {:transport, :connect, _url, _headers}
  end

  test "a mismatched provider output format fails closed" do
    {:ok, provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    send(provider, {:elevenlabs_agents_transport, :text, Jason.encode!(metadata_frame("pcm_24000"))})

    assert_receive {:voice_conversation, ^provider,
                    %Events.Error{code: :provider_error, message: "Voice assistant audio format mismatch."}}
  end

  test "context and user text use their documented frame names" do
    {:ok, provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    :ok = ElevenLabsAgents.send_context(provider, "build passed")
    :ok = ElevenLabsAgents.send_user_text(provider, "what changed?")

    assert_receive {:transport, :send, context}
    assert Jason.decode!(context) == %{"text" => "build passed", "type" => "contextual_update"}
    assert_receive {:transport, :send, user_text}
    assert Jason.decode!(user_text) == %{"text" => "what changed?", "type" => "user_message"}
  end

  test "close releases the websocket" do
    {:ok, provider} = ElevenLabsAgents.open(spec())
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    :ok = ElevenLabsAgents.close(provider)

    assert_receive {:transport, :close, :fake_socket}
  end

  test "the adapter closes its websocket when its owner dies" do
    test_pid = self()
    session = spec(owner: :placeholder)

    owner =
      spawn(fn ->
        {:ok, provider} = ElevenLabsAgents.open(%{session | owner: self()})
        send(test_pid, {:opened, provider})
        receive(do: (:keep_alive -> :ok))
      end)

    assert_receive {:opened, _provider}
    assert_receive {:http, _url, _headers}
    assert_receive {:transport, :connect, @signed_url, []}
    assert_initiation_frame()

    Process.exit(owner, :kill)

    assert_receive {:transport, :close, :fake_socket}
  end

  defp spec(overrides \\ []) do
    owner = self()

    Map.merge(
      %{
        owner: self(),
        credentials: {StaticCredentials, :elevenlabs},
        agent_id: "agent-1",
        system_prompt: "system",
        context: "context",
        first_message: "Hello",
        voice_id: "voice-1",
        tools: [],
        audio_in: :pcm_16000,
        audio_out: :pcm_16000,
        http: fn url, opts -> signed_url_http(owner, url, opts) end,
        transport: Transport
      },
      Map.new(overrides)
    )
  end

  defp signed_url_http(owner, url, opts) do
    send(owner, {:http, url, Keyword.fetch!(opts, :headers)})
    {:ok, 200, Jason.encode!(%{signed_url: @signed_url})}
  end

  defp http_response(status, body), do: fn _url, _opts -> {:ok, status, body} end

  defp metadata(provider),
    do: send(provider, {:elevenlabs_agents_transport, :text, Jason.encode!(metadata_frame("pcm_16000"))})

  defp metadata_frame(format) do
    %{
      type: "conversation_initiation_metadata",
      conversation_initiation_metadata_event: %{conversation_id: "conversation-1", agent_output_audio_format: format}
    }
  end

  defp assert_initiation_frame do
    assert_receive {:transport, :send, text}
    frame = Jason.decode!(text)
    assert frame["type"] == "conversation_initiation_client_data"
    frame
  end

  defp audio_frame do
    assert_receive {:transport, :send, text}
    frame = Jason.decode!(text)
    assert frame["type"] == "user_audio_chunk"
    frame["audio_base_64"]
  end
end
