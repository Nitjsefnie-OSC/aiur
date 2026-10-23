defmodule Aiur.BuildOrder.Index.PackRows do
  @moduledoc false

  @spec merge(map(), term()) :: map()
  def merge(all, %{rows: rows, aliases: aliases}) do
    all = Map.new(all, fn {id, row} -> {id, Map.put(row, :was, Map.get(aliases, row.num))} end)
    all = Enum.reduce(rows, all, &Map.put(&2, &1.id, %{&1 | epic: &1.epic || "unsorted"}))

    Enum.reduce(rows, all, fn row, acc ->
      Enum.reduce(row.deps, acc, fn dep, joined ->
        if Map.has_key?(joined, dep), do: Map.update!(joined, dep, &Map.update!(&1, :children, fn children -> Enum.uniq(children ++ [row.id]) end)), else: joined
      end)
    end)
  end

  def merge(all, _packs), do: all
end
