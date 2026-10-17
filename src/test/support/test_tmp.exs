defmodule Aiur.TestTmp do
  @moduledoc false

  def start!(base) do
    File.mkdir_p!(base)
    {uid, 0} = System.cmd("id", ["-u"])
    owner = uid |> String.trim() |> String.to_integer()
    %File.Stat{type: :directory, uid: ^owner} = File.lstat!(base)
    sweep!(base, owner)
    root = Path.join(base, "run-#{System.os_time(:millisecond)}-#{System.pid()}-#{System.unique_integer([:positive])}")
    File.mkdir!(root)
    File.chmod!(root, 0o700)
    ExUnit.after_suite(fn _result -> File.rm_rf!(root) end)
    root
  end

  # `rm` replaces the remover so a test can stage a leftover the sweep cannot delete.
  def sweep!(base, owner, rm \\ &writable_rm_rf/1) do
    for name <- File.ls!(base) do
      case Regex.run(~r/^(?:run-\d+|workflow)-(\d+)-\d+$/, name) do
        [_, pid] -> remove_dead_run!(Path.join(base, name), owner, String.to_integer(pid), rm)
        nil -> :ok
      end
    end
  end

  defp remove_dead_run!(path, owner, pid, rm) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory, uid: ^owner}} ->
        unless Aiur.ProcessIdentity.alive?(pid), do: remove_or_warn(path, rm)

      {:ok, _stat} ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        raise File.Error, reason: reason, action: "stat", path: path
    end
  end

  # A leaked build-gate runner leaves read-only hook snapshots, and rm_rf cannot clear a 0555 directory.
  # chmod -R does not follow symlinks, so this stays inside the run directory.
  defp writable_rm_rf(path) do
    _ = System.cmd("chmod", ["-R", "u+w", path], stderr_to_stdout: true)
    File.rm_rf(path)
  end

  # A stale run we cannot delete (say, files another uid wrote) must never block test boot.
  defp remove_or_warn(path, rm) do
    case rm.(path) do
      {:ok, _removed} ->
        :ok

      {:error, reason, file} ->
        IO.puts(:stderr, "warning: TestTmp sweep skipped #{path}: cannot remove #{file} (#{:file.format_error(reason)})")
    end
  end
end
