defmodule AiurWeb.DashboardAuth.ChallengeStore do
  @moduledoc false
  use GenServer

  @ttl_ms 3 * 60 * 1_000
  @max_entries 1_024

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, Keyword.put_new(opts, :name, __MODULE__))
  @spec put(Wax.Challenge.t(), GenServer.server()) :: {:ok, String.t()} | {:error, :capacity_exceeded}
  def put(challenge, server \\ __MODULE__), do: GenServer.call(server, {:put, challenge})
  @spec take(String.t(), GenServer.server()) :: {:ok, Wax.Challenge.t()} | {:error, :challenge_missing_or_replayed}
  def take(id, server \\ __MODULE__), do: GenServer.call(server, {:take, id})

  @impl GenServer
  def init(opts), do: {:ok, %{entries: %{}, ttl_ms: Keyword.get(opts, :ttl_ms, @ttl_ms), max_entries: Keyword.get(opts, :max_entries, @max_entries)}}

  @impl GenServer
  def handle_call({:put, %Wax.Challenge{} = challenge}, _from, state) do
    entries = purge_expired(state.entries)

    if map_size(entries) >= state.max_entries do
      {:reply, {:error, :capacity_exceeded}, %{state | entries: entries}}
    else
      id = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
      expires_at = System.monotonic_time(:millisecond) + state.ttl_ms
      {:reply, {:ok, id}, %{state | entries: Map.put(entries, id, {expires_at, challenge})}}
    end
  end

  def handle_call({:take, id}, _from, state) do
    entries = purge_expired(state.entries)

    case Map.pop(entries, id) do
      {{_expires_at, challenge}, rest} -> {:reply, {:ok, challenge}, %{state | entries: rest}}
      {nil, rest} -> {:reply, {:error, :challenge_missing_or_replayed}, %{state | entries: rest}}
    end
  end

  defp purge_expired(state) do
    now = System.monotonic_time(:millisecond)
    Map.reject(state, fn {_id, {expires_at, _challenge}} -> expires_at <= now end)
  end
end
