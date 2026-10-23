defmodule AiurWeb.DashboardAuth.ChallengeStore do
  @moduledoc false
  use GenServer

  @ttl_ms 20 * 60 * 1_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  @spec put(Wax.Challenge.t(), GenServer.server()) :: {:ok, String.t()}
  def put(challenge, server \\ __MODULE__), do: GenServer.call(server, {:put, challenge})
  @spec take(String.t(), GenServer.server()) :: {:ok, Wax.Challenge.t()} | {:error, :challenge_missing_or_replayed}
  def take(id, server \\ __MODULE__), do: GenServer.call(server, {:take, id})

  @impl GenServer
  def init(:ok), do: {:ok, %{}}

  @impl GenServer
  def handle_call({:put, %Wax.Challenge{} = challenge}, _from, state) do
    state = purge_expired(state)
    id = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    {:reply, {:ok, id}, Map.put(state, id, {System.monotonic_time(:millisecond) + @ttl_ms, challenge})}
  end

  def handle_call({:take, id}, _from, state) do
    state = purge_expired(state)

    case Map.pop(state, id) do
      {{_expires_at, challenge}, rest} -> {:reply, {:ok, challenge}, rest}
      {nil, rest} -> {:reply, {:error, :challenge_missing_or_replayed}, rest}
    end
  end

  defp purge_expired(state) do
    now = System.monotonic_time(:millisecond)
    Map.reject(state, fn {_id, {expires_at, _challenge}} -> expires_at <= now end)
  end
end
