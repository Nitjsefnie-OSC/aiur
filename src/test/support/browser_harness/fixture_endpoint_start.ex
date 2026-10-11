defmodule Aiur.BrowserHarness.FixtureEndpointStart do
  @moduledoc false

  @port_retries 5

  def start(start_fun, port, retries \\ @port_retries)
  def start(_start_fun, _port, 0), do: {:error, :eaddrinuse}

  def start(start_fun, port, retries) do
    case start_fun.(port) do
      {:error, {:shutdown, {:failed_to_start_child, :listener, :eaddrinuse}}} -> start(start_fun, 0, retries - 1)
      result -> result
    end
  end
end
