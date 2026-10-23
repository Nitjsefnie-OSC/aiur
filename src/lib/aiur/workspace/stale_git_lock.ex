defmodule Aiur.Workspace.StaleGitLock do
  @moduledoc "Conservative recovery for abandoned local Git index locks."

  require Logger

  @stale_after_seconds 120

  @doc false
  @spec recover(Path.t(), String.t() | nil, keyword()) :: :ok | {:error, term()}
  def recover(workspace, worker_host, opts \\ [])

  def recover(_workspace, worker_host, _opts) when is_binary(worker_host), do: :ok

  def recover(workspace, nil, opts) when is_binary(workspace) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    holder_probe = Keyword.get(opts, :holder_probe, &open_file_holders/1)

    workspace
    |> lock_paths()
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case recover_lock(path, now, holder_probe) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp lock_paths(workspace) do
    [Path.join(workspace, ".git"), Path.join(workspace, ".git-writable")]
    |> Enum.map(&Path.join(&1, "index.lock"))
  end

  defp recover_lock(path, now, holder_probe) do
    case File.lstat(path, time: :posix) do
      {:error, :enoent} ->
        :ok

      {:ok, %File.Stat{type: :regular, mtime: mtime, size: size}} ->
        age = max(DateTime.to_unix(now) - mtime, 0)

        if age < @stale_after_seconds do
          {:error, {:git_index_lock_too_young, path, age, size}}
        else
          remove_if_unheld(path, age, size, holder_probe)
        end

      {:ok, _stat} ->
        {:error, {:git_index_lock_invalid_type, path}}

      {:error, reason} ->
        {:error, {:git_index_lock_stat_failed, path, reason}}
    end
  end

  defp remove_if_unheld(path, age, size, holder_probe) do
    case holder_probe.(path) do
      {:ok, []} ->
        case File.rm(path) do
          :ok ->
            Logger.warning("Removed stale Git index lock path=#{path} age_seconds=#{age} size_bytes=#{size}")
            :ok

          {:error, :enoent} ->
            :ok

          {:error, reason} ->
            {:error, {:git_index_lock_remove_failed, path, age, size, reason}}
        end

      {:ok, [pid | _]} ->
        {:error, {:git_index_lock_held, path, age, size, pid}}

      {:error, reason} ->
        {:error, {:git_index_lock_holder_check_failed, path, age, size, reason}}
    end
  end

  defp open_file_holders(path) do
    with {:ok, %File.Stat{uid: expected_uid}} <- File.stat(path),
         {:ok, entries} <- File.ls("/proc") do
      scan_processes(entries, path, expected_uid)
    else
      {:error, :enoent} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp scan_processes(entries, path, expected_uid) do
    entries
    |> Enum.filter(fn pid ->
      Regex.match?(~r/^\d+$/, pid) and same_user_process?(pid, expected_uid)
    end)
    |> Enum.reduce_while({:ok, []}, &collect_holder(&1, &2, path))
    |> case do
      {:ok, holders} -> {:ok, holders |> Enum.uniq() |> Enum.sort()}
      {:error, _reason} = error -> error
    end
  end

  defp collect_holder(pid, {:ok, holders}, path) do
    case process_open_file(pid, path) do
      {:ok, nil} -> {:cont, {:ok, holders}}
      {:ok, holder} -> {:cont, {:ok, [holder | holders]}}
      {:error, reason} -> {:halt, {:error, {pid, reason}}}
    end
  end

  defp same_user_process?(pid, expected_uid) do
    case File.stat(Path.join(["/proc", pid])) do
      {:ok, %File.Stat{uid: ^expected_uid}} -> true
      {:error, :enoent} -> false
      {:error, :eacces} -> false
      {:ok, _stat} -> false
      {:error, _reason} -> false
    end
  end

  defp process_open_file(pid, path) do
    fd_dir = Path.join(["/proc", pid, "fd"])

    case File.ls(fd_dir) do
      {:ok, descriptors} ->
        case Enum.find(descriptors, &(File.read_link(Path.join(fd_dir, &1)) == {:ok, path})) do
          nil -> {:ok, nil}
          _fd -> {:ok, String.to_integer(pid)}
        end

      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
