defmodule VoiceConverse.Provider.ElevenLabsAgents.MintSocket do
  @moduledoc false

  use GenServer

  @message_tag :elevenlabs_agents_transport
  @connect_timeout_ms 5_000

  @spec start(pid(), String.t(), [{String.t(), String.t()}]) :: {:ok, pid()} | {:error, term()}
  def start(session, url, headers), do: GenServer.start(__MODULE__, {session, url, headers})

  @spec send_text(pid(), String.t()) :: :ok | {:error, term()}
  def send_text(socket, text), do: GenServer.call(socket, {:send_text, text})

  @spec close(pid()) :: :ok
  def close(socket) do
    GenServer.stop(socket, :normal)
  catch
    :exit, _reason -> :ok
  end

  @impl true
  def init({session, url, headers}) do
    Process.monitor(session)

    with {:ok, target} <- target(url),
         {:ok, conn} <- Mint.HTTP.connect(target.scheme, target.host, target.port, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(target.ws_scheme, conn, target.path, headers) do
      {:ok, %{session: session, conn: conn, ref: ref, websocket: nil, pending: [], status: nil, headers: []},
       @connect_timeout_ms}
    else
      _unreachable -> {:stop, :connect_failed}
    end
  end

  @impl true
  def handle_call({:send_text, _text}, _from, %{websocket: nil} = state), do: {:reply, {:error, :not_ready}, state}

  def handle_call({:send_text, text}, _from, state) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, {:text, text}),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, state.ref, data) do
      {:reply, :ok, %{state | websocket: websocket, conn: conn}}
    else
      _unreachable -> {:reply, {:error, :send_failed}, state}
    end
  end

  @impl true
  def handle_info(:timeout, state), do: transport_failed(state)

  def handle_info({:DOWN, _ref, :process, session, _reason}, %{session: session} = state), do: {:stop, :normal, state}

  def handle_info(message, state) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} -> Enum.reduce_while(responses, {:noreply, %{state | conn: conn}}, &handle_response/2)
      {:error, conn, _reason, _responses} -> transport_failed(%{state | conn: conn})
      :unknown -> {:noreply, state}
    end
  end

  defp handle_response({:status, ref, status}, {:noreply, %{ref: ref} = state}),
    do: {:cont, {:noreply, %{state | status: status}}}

  defp handle_response({:headers, ref, headers}, {:noreply, %{ref: ref} = state}),
    do: {:cont, {:noreply, %{state | headers: headers}}}

  defp handle_response({:done, ref}, {:noreply, %{ref: ref} = state}) do
    case Mint.WebSocket.new(state.conn, ref, state.status, state.headers) do
      {:ok, conn, websocket} ->
        state = %{state | conn: conn, websocket: websocket}
        pending = Enum.reverse(state.pending)
        {:cont, Enum.reduce_while(pending, {:noreply, %{state | pending: []}}, &decode_frames/2)}

      {:error, conn, _reason} ->
        {:halt, transport_failed(%{state | conn: conn})}
    end
  end

  defp handle_response({:data, ref, data}, {:noreply, %{ref: ref, websocket: nil} = state}),
    do: {:cont, {:noreply, %{state | pending: [data | state.pending]}}}

  defp handle_response({:data, ref, data}, {:noreply, %{ref: ref} = state}), do: decode_frames(data, {:noreply, state})
  defp handle_response({:error, ref, _reason}, {:noreply, %{ref: ref} = state}), do: {:halt, transport_failed(state)}
  defp handle_response(_response, acc), do: {:cont, acc}

  defp decode_frames(data, {:noreply, state}) do
    case Mint.WebSocket.decode(state.websocket, data) do
      {:ok, websocket, frames} -> {:cont, deliver(%{state | websocket: websocket}, frames)}
      {:error, websocket, _reason} -> {:halt, transport_failed(%{state | websocket: websocket})}
    end
  end

  defp deliver(state, frames) do
    Enum.reduce_while(frames, {:noreply, state}, fn
      {:text, text}, {:noreply, state} ->
        send(state.session, {@message_tag, :text, text})
        {:cont, {:noreply, state}}

      {:close, _code, _reason}, {:noreply, state} ->
        send(state.session, {@message_tag, :closed})
        {:halt, {:stop, :normal, state}}

      _frame, acc ->
        {:cont, acc}
    end)
  end

  defp transport_failed(state) do
    send(state.session, {@message_tag, :error, :transport})
    {:stop, :normal, state}
  end

  defp target(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri when scheme in ["wss", "https"] and is_binary(host) ->
        {:ok, %{scheme: :https, ws_scheme: :wss, host: host, port: uri.port || 443, path: path(uri)}}

      %URI{scheme: scheme, host: host} = uri when scheme in ["ws", "http"] and is_binary(host) ->
        {:ok, %{scheme: :http, ws_scheme: :ws, host: host, port: uri.port || 80, path: path(uri)}}

      _unsupported ->
        {:error, :unsupported_url}
    end
  end

  defp path(%URI{path: path, query: nil}), do: path || "/"
  defp path(%URI{path: path, query: query}), do: (path || "/") <> "?" <> query
end
