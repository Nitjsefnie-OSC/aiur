defmodule Aiur.ControlCallTest do
  use ExUnit.Case, async: true

  alias Aiur.ControlCall

  test "parses an allowlisted literal call and refuses a foreign module" do
    assert {:ok, %{module: Aiur.AgentControlCLI, function: :agents, args: [[all: true]], scope: :read}} =
             ControlCall.parse("Aiur.AgentControlCLI.agents(all: true)")

    assert {:error, :not_allowlisted} = ControlCall.parse("System.cmd(\"id\", [])")
    assert {:error, :non_literal_argument} = ControlCall.parse(~s|Aiur.AgentControlCLI.message("1", File.read!("/etc/passwd"))|)
  end

  test "rejects executable and non-single-call syntax" do
    for expression <- [
          "Aiur.AgentControlCLI.status() |> System.cmd(\"id\", [])",
          "~s|Aiur.AgentControlCLI.status()|",
          "&System.cmd/2",
          "apply(System, :cmd, [\"id\", []])",
          "Aiur.AgentControlCLI.status(); System.cmd(\"id\", [])",
          "Aiur.AgentControlCLI.status(nested: fn -> :ok end)"
        ] do
      assert {:error, _reason} = ControlCall.parse(expression), expression
    end
  end

  test "distinguishes unsupported options, unavailable build names and denied calls" do
    assert {:error, :option_not_allowed} = ControlCall.parse("Aiur.HarnessSessionCLI.rpc(path: \"/etc/passwd\")")
    assert {:error, :option_not_allowed} = ControlCall.parse("Aiur.AgentControlCLI.queue(server: :foo)")
    assert {:error, :option_not_allowed} = ControlCall.parse("Aiur.AgentControlCLI.analytics(telemetry_file: \"/x\")")
    assert {:error, {:unknown_on_build, "function_from_the_future"}} = ControlCall.parse("Aiur.AgentControlCLI.function_from_the_future()")
    assert {:error, {:unknown_on_build, "future_key_qq"}} = ControlCall.parse("Aiur.AgentControlCLI.executor_wait(future_key_qq: 1)")
    assert {:error, {:unknown_on_build, "list"}} = ControlCall.parse("Aiur.AgentControlCLI.list()")
    assert {:error, {:unknown_on_build, "some_registered_name"}} = ControlCall.parse("Aiur.AgentControlCLI.usage(:some_registered_name)")
    assert {:error, :denied_remote} = ControlCall.parse(~s|Aiur.AgentControlCLI.operator_answer(decision_id: "d", operator: true, option_id: "o", expected_version: 1, confirmation: "d")|)
  end

  test "classifies mutating verbs and enforces maximum scope" do
    assert {:ok, %{scope: :write}} = ControlCall.parse("Aiur.AgentControlCLI.set_max_agents(2)")
    assert {:ok, %{scope: :write}} = ControlCall.parse("Aiur.AgentControlCLI.executor_wait(timeout_ms: 300000, json: true)")
    assert {:ok, %{scope: :read}} = ControlCall.parse("Aiur.AgentControlCLI.executor_roster(json: true)")
    assert {:ok, %{scope: :read}} = ControlCall.parse("Aiur.AgentControlCLI.status()")
    assert {:ok, %{scope: :read}} = ControlCall.parse("Aiur.AgentControlCLI.watch(mode: :full)")
    assert {:ok, %{scope: :write}} = ControlCall.parse("Aiur.AgentControlCLI.watch()")
    assert {:error, :scope_exceeds_max} = ControlCall.parse("Aiur.AgentControlCLI.set_max_agents(2)", max_scope: :read)
  end

  test "remote calls cannot provide identity overrides or executor session env" do
    assert {:error, :option_not_allowed} = ControlCall.parse(~s|Aiur.AgentControlCLI.feature(argv: ["create"], who: "operator")|, remote: true)
    assert {:error, :option_not_allowed} = ControlCall.parse(~s|Aiur.AgentControlCLI.executor_wait(env: [{"CLAUDE_PID", "12"}])|, remote: true)
  end

  test "direct actor defaults to a local identity" do
    assert ControlCall.actor() == "local:" <> (System.get_env("USER") || "unknown")
  end

  test "run captures output from an allowlisted read call" do
    assert {:ok, parsed} = ControlCall.parse("Aiur.AgentControlCLI.executor_subscriptions()")
    assert {:ok, output} = ControlCall.run(parsed, 1_000, "token:t")
    assert String.ends_with?(output, "__AIUR_CONTROL_EXIT__:0\n")
  end

  test "run captures task failures without taking down its caller" do
    assert {:ok, parsed} = ControlCall.parse("Aiur.AgentControlCLI.executor_subscriptions()")
    parent = self()

    caller =
      Task.async(fn ->
        Process.flag(:trap_exit, true)
        send(parent, {:alive_before, self()})
        result = ControlCall.run(parsed, 1_000, "token:t")
        send(parent, {:result, result})

        receive do
          :stop -> :ok
        end
      end)

    assert {:alive_before, caller_pid} = receive_message()
    assert {:result, {:ok, output}} = receive_message()
    assert String.ends_with?(output, "__AIUR_CONTROL_EXIT__:0\n")
    assert Process.alive?(caller_pid)
    send(caller.pid, :stop)
    assert Task.await(caller) == :ok
  end

  test "run applies distinct read and write timeout policies" do
    assert {:ok, read_call} = ControlCall.parse("Aiur.AgentControlCLI.executor_subscriptions()")
    assert {:ok, write_call} = ControlCall.parse("Aiur.AgentControlCLI.set_max_agents(2)")

    assert {:error, :timeout} = ControlCall.run(read_call, 0, "token:t")
    assert {:error, :timeout} = ControlCall.run(write_call, 0, "token:t")
  end

  defp receive_message do
    receive do
      message -> message
    after
      1_000 -> flunk("expected message from isolated caller")
    end
  end
end
