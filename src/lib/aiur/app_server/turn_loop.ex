defmodule Aiur.AppServer.TurnLoop do
  @moduledoc """
  Shared blocking receive loop for app-server turns.
  """

  alias Aiur.AgentRunner.Handoff
  alias Aiur.AppServer.{Adapter, Interrupts, Messages, OperatorDelivery, Rpc, TurnState}
  alias Aiur.AppServer.Rpc.StreamDiagnostics

  @completion_output_quiet_ms 25
  @completion_output_max_ms 100

  @spec receive_loop(map(), map()) :: term()
  def receive_loop(session, state) do
    case Process.get(:handoff_replay_frames, []) do
      [frame | rest] ->
        Process.put(:handoff_replay_frames, rest)
        continue_or_return(session, replay_frame(session, state, frame), state)

      [] ->
        receive_messages(session, state)
    end
  end

  defp replay_frame(session, state, {:data, {:eol, chunk}}),
    do: handle_incoming(session, %{state | pending_line: ""}, state.pending_line <> to_string(chunk))

  defp replay_frame(_session, state, {:data, {:noeol, chunk}}),
    do: {:continue, %{state | pending_line: state.pending_line <> to_string(chunk)}}

  defp replay_frame(session, state, {:exit_status, status}), do: handle_port_exit(session, state, status)

  defp receive_messages(%{port: port} = session, state) do
    receive do
      :handoff_abort ->
        Process.delete(:handoff_hold)
        receive_loop(session, state)

      :handoff_hold ->
        Process.put(:handoff_hold, true)
        receive_loop(session, state)

      {:handoff_snapshot, from, ref} ->
        Handoff.capture(session, state, from, ref)

      {^port, {:data, {:eol, chunk}}} ->
        complete_line = state.pending_line <> to_string(chunk)
        continue_or_return(session, handle_incoming(session, %{state | pending_line: ""}, complete_line), state)

      {^port, {:data, {:noeol, chunk}}} ->
        receive_loop(session, %{state | pending_line: state.pending_line <> to_string(chunk)})

      {^port, {:exit_status, status}} ->
        handle_port_exit(session, state, status)

      {:DOWN, _ref, :port, ^port, reason} ->
        port_exit_failure(session, state, reason)

      {:pause_agent, request_id, generation} when is_integer(request_id) and is_integer(generation) ->
        continue_or_return(
          session,
          Interrupts.handle_pause_request(session, state, %{request_id: request_id, generation: generation})
        )

      {:pause_agent, request_id} when is_integer(request_id) ->
        continue_or_return(session, Interrupts.handle_pause_request(session, state, request_id))

      {:agent_queue_updated, issue_identifier, _item_id, true}
      when issue_identifier == state.issue_identifier ->
        continue_or_return(session, Interrupts.handle_operator_queue_update(session, state))

      {:agent_queue_updated, issue_identifier, _item_id, _deliver_now}
      when issue_identifier == state.issue_identifier ->
        receive_loop(session, state)

      {:agent_queue_updated, issue_identifier, _item_id}
      when issue_identifier == state.issue_identifier ->
        receive_loop(session, state)

      {:agent_queue_updated, _issue_identifier, _item_id, _deliver_now} ->
        receive_loop(session, state)

      {:agent_queue_updated, _issue_identifier, _item_id} ->
        receive_loop(session, state)
    after
      state.timeout_ms ->
        {:error, :turn_timeout}
    end
  end

  defp continue_or_return(session, {:continue, next_state}), do: receive_loop(session, next_state)
  defp continue_or_return(_session, result), do: result

  defp continue_or_return(session, {:continue, next_state}, _state), do: receive_loop(session, next_state)

  defp continue_or_return(session, {:ok, :turn_completed} = result, state) do
    deadline = System.monotonic_time(:millisecond) + @completion_output_max_ms
    drain_completion_output(session, state, "", deadline)
    result
  end

  defp continue_or_return(_session, result, _state), do: result

  # The app-server combines stdout and stderr, but the BEAM can deliver the
  # terminal JSON frame before stderr written by the same child. Drain a short
  # quiet window, with a hard cap, before the caller tears down the port.
  defp drain_completion_output(%{port: port} = session, state, pending_line, deadline) do
    remaining_ms = deadline - System.monotonic_time(:millisecond)

    if remaining_ms > 0 do
      receive do
        {^port, {:data, {:eol, chunk}}} ->
          line = pending_line <> to_string(chunk)

          case Jason.decode(line) do
            {:ok, _payload} ->
              drain_completion_output(session, state, "", deadline)

            {:error, _reason} ->
              _ = handle_incoming(session, Map.put(state, :pending_line, ""), line)
              drain_completion_output(session, state, "", deadline)
          end

        {^port, {:data, {:noeol, chunk}}} ->
          drain_completion_output(session, state, pending_line <> to_string(chunk), deadline)
      after
        min(@completion_output_quiet_ms, remaining_ms) ->
          finish_completion_output_drain(session, state, pending_line)
      end
    else
      finish_completion_output_drain(session, state, pending_line)
    end
  end

  defp finish_completion_output_drain(session, state, pending_line) do
    if pending_line != "" do
      case Jason.decode(pending_line) do
        {:ok, _payload} ->
          :ok

        {:error, _reason} ->
          _ = handle_incoming(session, Map.put(state, :pending_line, ""), pending_line)
      end
    end

    :ok
  end

  defp handle_incoming(%{port: port} = session, state, data) do
    on_message = state.on_message
    payload_string = to_string(data)

    if Rpc.discard_late_sensitive_response?(port, payload_string) do
      {:continue, state}
    else
      case Jason.decode(payload_string) do
        {:ok, payload} ->
          handle_decoded_incoming(session, state, payload, payload_string, port, on_message)

        {:error, _reason} ->
          StreamDiagnostics.record(port, payload_string)
          state.backend.handle_malformed(state, payload_string, port)
      end
    end
  end

  defp handle_decoded_incoming(_session, state, %{"id" => request_id, "result" => _} = payload, _payload_string, _port, _on_message)
       when request_id == state.pending_interrupt_request_id do
    TurnState.acknowledge_interrupt(state, payload)
  end

  defp handle_decoded_incoming(_session, state, %{"id" => request_id, "error" => error}, _payload_string, _port, _on_message)
       when request_id == state.pending_interrupt_request_id do
    state.backend.handle_interrupt_error(state, error)
  end

  defp handle_decoded_incoming(session, state, %{"id" => request_id, "result" => _} = payload, payload_string, _port, _on_message)
       when is_integer(request_id) do
    OperatorDelivery.handle_pending_operator_response(session, state, payload, payload_string, request_id)
  end

  defp handle_decoded_incoming(session, state, %{"id" => request_id, "error" => _} = payload, payload_string, _port, _on_message)
       when is_integer(request_id) do
    OperatorDelivery.handle_pending_operator_response(session, state, payload, payload_string, request_id)
  end

  defp handle_decoded_incoming(session, state, %{"method" => method} = payload, payload_string, _port, _on_message)
       when is_binary(method) do
    state.backend.handle_method(session, state, payload, payload_string, method)
  end

  defp handle_decoded_incoming(_session, state, payload, payload_string, port, on_message) do
    Messages.emit_message(
      on_message,
      :other_message,
      %{
        payload: payload,
        raw: payload_string
      },
      state.backend.metadata_from_message(port, payload)
    )

    {:continue, state}
  end

  defp resolve_pending_anonymous_completion(%{pending_anonymous_completion?: true} = state) do
    payload = %{
      "params" => %{
        "turn" => %{
          "id" => state.current_turn_id,
          "status" => "completed"
        }
      }
    }

    state
    |> Map.put(:pending_anonymous_completion?, false)
    |> TurnState.continue_after_turn_completion(payload)
  end

  defp resolve_pending_anonymous_completion(_state), do: :none

  defp handle_port_exit(session, state, 0) do
    case resolve_pending_anonymous_completion(state) do
      :none -> port_exit_failure(session, state, 0)
      {:continue, _next_state} -> port_exit_failure(session, state, 0)
      result -> result
    end
  end

  defp handle_port_exit(session, state, status), do: port_exit_failure(session, state, status)

  # A provider CLI that refuses the turn because the account is out of quota
  # prints its refusal and exits, so the exit status alone says nothing. Give
  # the backend the retained non-JSON stream output first: a recognised
  # exhaustion signature is a pause (which the rate-limit fallback acts on),
  # not a turn failure that burns the ticket's retries (#2607).
  defp port_exit_failure(session, state, status) do
    case Adapter.classify_stream_failure(state.backend, StreamDiagnostics.recent_text(session.port)) do
      {:paused, payload} -> {:paused, payload}
      :unclassified -> {:error, {:port_exit, status}}
    end
  end
end
