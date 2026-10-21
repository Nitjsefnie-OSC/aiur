defmodule AiurWeb.Build.ControlFixtureTest do
  use ExUnit.Case, async: false
  alias Aiur.TestSupport.BuildHome.ControlFixture

  test "reset completes even when loading parity selected the blocking dataset" do
    previous = Application.fetch_env(:aiur, :build_fixture_dataset)
    Application.put_env(:aiur, :build_fixture_dataset, "hold")

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:aiur, :build_fixture_dataset, value)
        :error -> Application.delete_env(:aiur, :build_fixture_dataset)
      end
    end)

    task = Task.async(&ControlFixture.reset/0)
    result = Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill)
    assert result == {:ok, :ok}
    assert Application.fetch_env!(:aiur, :build_fixture_dataset) == "hold"
  end
end
