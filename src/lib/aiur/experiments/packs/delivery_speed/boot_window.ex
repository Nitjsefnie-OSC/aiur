defmodule Aiur.Experiments.Packs.DeliverySpeed.BootWindow do
  @moduledoc "Bounded inspection of ordered summary records; unknown bounds remain eligible."
  alias Aiur.Experiments.Sources.Common
  @prefix_bytes 65_536

  @spec before_end?(Path.t(), String.t(), DateTime.t()) :: boolean()
  def before_end?(path, boot, finish) do
    case first_event(path, boot) do
      %DateTime{} = at -> DateTime.compare(at, finish) == :lt
      nil -> true
    end
  end

  defp first_event(path, boot) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        try do
          prefix = IO.binread(file, @prefix_bytes)
          inspect_prefix(prefix, boot)
        after
          File.close(file)
        end

      {:error, _reason} ->
        nil
    end
  end

  defp inspect_prefix(prefix, boot) when is_binary(prefix) do
    decoders = %{
      object_start: fn _old -> %{} end,
      object_push: fn key, value, object -> Map.put(object, key, value) end,
      object_finish: fn object, old ->
        if object["boot_id"] in [boot, "github"] and is_binary(object["kind"]), do: throw({:first_event, Common.timestamp(object["timestamp"])})
        {object, old}
      end
    }

    :json.decode_start(prefix, nil, decoders)
    nil
  rescue
    _invalid -> nil
  catch
    {:first_event, at} -> at
  end

  defp inspect_prefix(_missing, _boot), do: nil
end
