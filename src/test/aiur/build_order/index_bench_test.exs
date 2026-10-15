defmodule Aiur.BuildOrder.IndexBenchTest do
  use ExUnit.Case, async: false
  import Aiur.TestSupport.BuildHome.IndexParts
  alias Aiur.BuildOrder.Index
  @moduletag :perf_regression

  test "records 1400 and 10000 ticket assembly time, index size and page size" do
    for count <- [1_400, 10_000] do
      p = parts(for n <- 1..count, do: row(n, %{end: DateTime.add(~U[2026-10-07 12:00:00Z], -div(n, 50) * 86_400)}))
      {microseconds, {:ok, index}} = :timer.tc(fn -> assemble(p) end)
      bytes = :erts_debug.flat_size(index) * :erlang.system_info(:wordsize)
      page = Index.window(index, "America/Los_Angeles", now())
      IO.puts("INDEX_BENCH tickets=#{count} assemble_ms=#{microseconds / 1_000} index_bytes=#{bytes} page_rows=#{length(page.sections.hist)}")
      assert map_size(index.all) == count
      if count == 1_400, do: assert(microseconds <= 250_000)
    end
  end
end
