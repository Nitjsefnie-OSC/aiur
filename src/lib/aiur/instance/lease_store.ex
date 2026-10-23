defmodule Aiur.Instance.LeaseStore do
  @moduledoc "Shared ticket leases and instance heartbeats backed by PostgreSQL."
  use GenServer

  require Logger

  alias Aiur.Instance.Identity

  @name __MODULE__
  @default_ttl_ms 30_000

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: @name,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @name))
  end

  @doc "Returns whether the coordination database is configured."
  @spec configured?() :: boolean()
  def configured? do
    is_binary(database_url()) and database_url() != ""
  end

  @doc "Atomically acquires an expired or unheld ticket lease."
  @spec claim(String.t(), keyword()) :: :acquired | :held | :disabled | {:error, term()}
  def claim(ticket_key, opts \\ []) when is_binary(ticket_key) do
    if configured?() do
      GenServer.call(
        Keyword.get(opts, :server, @name),
        {:claim, ticket_key, Keyword.get(opts, :ttl_ms, @default_ttl_ms)},
        10_000
      )
    else
      :disabled
    end
  catch
    :exit, reason -> {:error, {:store_unavailable, reason}}
  end

  @doc "Starts a renewal process that follows the current caller's lifetime."
  @spec watch(String.t(), keyword()) :: :ok | :not_owned | :disabled | {:error, term()}
  def watch(ticket_key, opts \\ []) when is_binary(ticket_key),
    do: watch_configured(ticket_key, Keyword.get(opts, :server, @name), opts)

  defp watch_configured(ticket_key, server, opts) do
    if configured?(), do: watch_owned(ticket_key, server, opts), else: :disabled
  catch
    :exit, reason -> {:error, {:store_unavailable, reason}}
  end

  defp watch_owned(ticket_key, server, opts) do
    case GenServer.call(server, {:watch, ticket_key}) do
      :ok ->
        parent = self()
        interval = Keyword.get(opts, :renew_interval_ms, div(@default_ttl_ms, 3))
        {:ok, _pid} = Task.start(fn -> renew_while_alive(parent, ticket_key, interval, server) end)
        :ok

      :not_owned ->
        :not_owned

      {:error, _} = error ->
        error
    end
  end

  @doc "Renews a ticket lease only while this instance still owns it."
  @spec renew(String.t(), keyword()) :: :ok | {:error, term()}
  def renew(ticket_key, opts \\ []) do
    request(opts, {:renew, ticket_key, Keyword.get(opts, :ttl_ms, @default_ttl_ms)})
  end

  @doc "Releases a ticket lease only while this instance still owns it."
  @spec release(String.t(), keyword()) :: :ok | {:error, term()}
  def release(ticket_key, opts \\ []), do: request(opts, {:release, ticket_key})

  @doc "Returns whether the current instance has a non-expired lease; store uncertainty fails closed."
  @spec owned?(String.t(), keyword()) :: boolean() | :disabled | :unknown
  def owned?(ticket_key, opts \\ []) when is_binary(ticket_key) do
    if configured?() do
      case request(opts, {:owned, ticket_key}) do
        {:ok, true} -> true
        {:ok, false} -> false
        {:error, _reason} -> :unknown
      end
    else
      :disabled
    end
  end

  @doc "Publishes this instance's opaque metadata and returns the live roster."
  @spec heartbeat(String.t(), map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def heartbeat(build_version, metadata, opts \\ [])
      when is_binary(build_version) and is_map(metadata) do
    request(
      opts,
      {:heartbeat, build_version, metadata, Keyword.get(opts, :ttl_ms, @default_ttl_ms * 3)}
    )
  end

  @doc "Lists live instance records; database errors are returned, never treated as an empty roster."
  @spec list_live(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_live(opts \\ []), do: request(opts, :list_live)

  @impl true
  def init(opts) do
    url = Keyword.get(opts, :url, database_url())

    case Postgrex.start_link(
           connection_opts(url) ++
             [name: Keyword.get(opts, :connection_name, __MODULE__.Connection), timeout: 5_000]
         ) do
      {:ok, conn} ->
        case create_tables(conn) do
          :ok ->
            {:ok,
             %{
               conn: conn,
               instance_id: Keyword.get(opts, :instance_id, &Identity.current/0),
               leases: MapSet.new()
             }}

          {:error, reason} ->
            {:stop, {:coordination_store_unavailable, reason}}
        end

      {:error, reason} ->
        {:stop, {:coordination_store_unavailable, reason}}
    end
  end

  @impl true
  def handle_call({:claim, key, ttl_ms}, _from, state) do
    instance_id = instance_id(state)

    result =
      query(
        state,
        """
        INSERT INTO aiur_ticket_leases (ticket_key, instance_id, heartbeat_at, expires_at)
        VALUES ($1, $2, clock_timestamp(), clock_timestamp() + make_interval(secs => $3))
        ON CONFLICT (ticket_key) DO UPDATE
        SET instance_id = EXCLUDED.instance_id, heartbeat_at = EXCLUDED.heartbeat_at, expires_at = EXCLUDED.expires_at
        WHERE aiur_ticket_leases.expires_at <= clock_timestamp()
           OR aiur_ticket_leases.instance_id = EXCLUDED.instance_id
        RETURNING ticket_key
        """,
        [key, instance_id, ttl_ms / 1_000],
        fn %{num_rows: rows} -> if(rows == 1, do: :acquired, else: :held) end
      )

    state =
      if result == :acquired, do: %{state | leases: MapSet.put(state.leases, key)}, else: state

    {:reply, result, state}
  end

  def handle_call({:watch, key}, _from, state),
    do: {:reply, if(MapSet.member?(state.leases, key), do: :ok, else: :not_owned), state}

  def handle_call({:renew, key, ttl_ms}, _from, state) do
    result =
      query(
        state,
        """
        UPDATE aiur_ticket_leases SET heartbeat_at = clock_timestamp(),
          expires_at = clock_timestamp() + make_interval(secs => $3)
        WHERE ticket_key = $1 AND instance_id = $2
        RETURNING ticket_key
        """,
        [key, instance_id(state), ttl_ms / 1_000],
        fn %{num_rows: rows} -> if(rows == 1, do: :ok, else: {:error, :lease_lost}) end
      )

    {:reply, result, state}
  end

  def handle_call({:release, key}, _from, state) do
    result =
      query(
        state,
        "DELETE FROM aiur_ticket_leases WHERE ticket_key = $1 AND instance_id = $2",
        [key, instance_id(state)],
        fn _ -> :ok end
      )

    state = if result == :ok, do: %{state | leases: MapSet.delete(state.leases, key)}, else: state
    {:reply, result, state}
  end

  def handle_call({:owned, key}, _from, state) do
    result =
      query(
        state,
        """
        SELECT ticket_key FROM aiur_ticket_leases
        WHERE ticket_key = $1 AND instance_id = $2 AND expires_at > clock_timestamp()
        """,
        [key, instance_id(state)],
        fn %{num_rows: rows} -> {:ok, rows == 1} end
      )

    {:reply, result, state}
  end

  def handle_call({:heartbeat, build_version, metadata, ttl_ms}, _from, state) do
    encoded = Jason.encode!(metadata)

    result =
      query(
        state,
        """
        INSERT INTO aiur_instances (instance_id, build_version, metadata_json, heartbeat_at, expires_at)
        VALUES ($1, $2, $3, clock_timestamp(), clock_timestamp() + make_interval(secs => $4))
        ON CONFLICT (instance_id) DO UPDATE SET build_version = EXCLUDED.build_version,
          metadata_json = EXCLUDED.metadata_json, heartbeat_at = EXCLUDED.heartbeat_at, expires_at = EXCLUDED.expires_at
        RETURNING instance_id, build_version, metadata_json, heartbeat_at, expires_at
        """,
        [instance_id(state), build_version, encoded, ttl_ms / 1_000],
        &decode_instances/1
      )

    {:reply, result, state}
  end

  def handle_call(:list_live, _from, state) do
    result =
      query(
        state,
        """
        SELECT instance_id, build_version, metadata_json, heartbeat_at, expires_at
        FROM aiur_instances WHERE expires_at > clock_timestamp() ORDER BY instance_id
        """,
        [],
        &decode_instances/1
      )

    {:reply, result, state}
  end

  defp request(opts, message) do
    if configured?(),
      do: GenServer.call(Keyword.get(opts, :server, @name), message, 10_000),
      else: {:error, :store_not_configured}
  catch
    :exit, reason -> {:error, {:store_unavailable, reason}}
  end

  defp query(state, sql, params, map_fun) do
    case Postgrex.query(state.conn, sql, params, timeout: 5_000) do
      {:ok, result} -> map_fun.(result)
      {:error, reason} -> {:error, {:store_unavailable, reason}}
    end
  rescue
    error -> {:error, {:store_unavailable, error}}
  end

  defp create_tables(conn) do
    with {:ok, _} <-
           Postgrex.query(
             conn,
             """
             CREATE TABLE IF NOT EXISTS aiur_ticket_leases (
               ticket_key text PRIMARY KEY,
               instance_id text NOT NULL,
               heartbeat_at timestamptz NOT NULL,
               expires_at timestamptz NOT NULL
             )
             """,
             []
           ),
         {:ok, _} <-
           Postgrex.query(
             conn,
             """
             CREATE TABLE IF NOT EXISTS aiur_instances (
               instance_id text PRIMARY KEY,
               build_version text NOT NULL,
               metadata_json text NOT NULL,
               heartbeat_at timestamptz NOT NULL,
               expires_at timestamptz NOT NULL
             )
             """,
             []
           ) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_instances(%{rows: rows}) do
    Enum.reduce_while(rows, {:ok, []}, fn [id, version, metadata, heartbeat_at, expires_at], {:ok, acc} ->
      case Jason.decode(metadata) do
        {:ok, decoded} when is_map(decoded) ->
          item = %{
            instance_id: id,
            build_version: version,
            metadata: decoded,
            heartbeat_at: heartbeat_at,
            expires_at: expires_at
          }

          {:cont, {:ok, [item | acc]}}

        _ ->
          {:halt, {:error, :invalid_instance_metadata}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp instance_id(state) do
    case state.instance_id do
      fun when is_function(fun, 0) -> fun.()
      id -> id
    end
  end

  defp renew_while_alive(parent, key, interval, server) do
    monitor = Process.monitor(parent)
    renew_loop(parent, monitor, key, interval, server)
  end

  defp renew_loop(parent, monitor, key, interval, server) do
    receive do
      {:DOWN, ^monitor, :process, ^parent, _reason} -> :ok
    after
      interval ->
        case renew(key, server: server) do
          :ok ->
            renew_loop(parent, monitor, key, interval, server)

          {:error, :lease_lost} ->
            Process.exit(parent, {:shared_ticket_lease_lost, key})

          {:error, reason} ->
            Logger.warning("ticket lease renewal unavailable key=#{key}: #{inspect(reason)}")
            renew_loop(parent, monitor, key, interval, server)
        end
    end
  end

  defp database_url do
    Application.get_env(:aiur, :lease_database_url) || System.get_env("AIUR_LEASE_DATABASE_URL")
  end

  defp connection_opts(url) do
    uri = URI.parse(url)
    [username, password] = String.split(uri.userinfo || ":", ":", parts: 2)
    database = uri.path |> to_string() |> String.trim_leading("/") |> URI.decode()
    remote? = uri.host not in [nil, "localhost", "127.0.0.1", "::1"]

    [
      hostname: uri.host,
      port: uri.port || 5432,
      username: URI.decode(username),
      password: URI.decode(password),
      database: database
    ] ++
      if(remote?, do: [ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()]], else: [])
  end
end
