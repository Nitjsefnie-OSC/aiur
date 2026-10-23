defmodule Aiur.ControlCall.EngineCensusTest do
  use ExUnit.Case, async: true

  alias Aiur.ControlCall
  alias Aiur.ControlCall.Allowlist

  @runtime_built [
    {"$expression: local/global control commands", :write},
    {"$expression: workspace ownership operations", :write},
    {"$expression: generated report command", :read_or_write},
    {"executor_wait optional identity/session arguments", :write},
    {"executor ownership keyword arguments", :write},
    {"Aiur.PrMerge.Record.publish/1 (piped expression)", :deny},
    {"AIUR_HANDOFF_PREPARE_EXPRESSION", :deny}
  ]

  test "every public AgentControlCLI function has an explicit classification" do
    classified =
      MapSet.new(
        Allowlist.entries()
        |> Enum.flat_map(fn
          {{[:Aiur, :AgentControlCLI], fun, arity}, _} -> [{fun, arity}]
          _ -> []
        end)
      )

    assert Enum.all?(Allowlist.facade_functions(), &MapSet.member?(classified, &1))
  end

  test "static engine RPC templates are explicitly enumerated and parse through existing_atoms_only" do
    root = Path.expand("../../../..", __DIR__)
    files = Path.wildcard(Path.join(root, "packaging/npm/aiur-cli/libexec/**/*.sh"))
    source = Enum.map_join(files, "\n", &File.read!/1)
    templates = Regex.scan(~r/run_control_rpc\s+"((?:\\\\.|[^"\\\\])*)"/s, source, capture: :all_but_first) |> List.flatten()

    assert templates != []

    static_templates = Enum.reject(templates, &runtime_template?/1)

    for template <- static_templates do
      expression = template |> String.replace(~r/\\"/, "\"") |> substitute_shell_values()

      case ControlCall.parse(expression) do
        {:ok, %{scope: scope}} when scope in [:read, :write] -> :ok
        {:error, :denied_remote} -> :ok
        result -> flunk("unclassified static RPC template #{template}: #{inspect(result)}")
      end
    end

    assert Enum.all?(@runtime_built, fn {_description, classification} -> classification in [:read, :write, :read_or_write, :deny] end)
  end

  defp runtime_template?(template),
    do: String.contains?(template, ["$expression", "${command}", "$(elixir_list_literal", "$(executor_as_argument", "$(executor_as_keyword", "AIUR_HANDOFF_PREPARE_EXPRESSION"])

  defp substitute_shell_values(template) do
    template
    |> String.replace("$opts", sample_options(template))
    |> String.replace("$preview_args", sample_options("operator_answer"))
    |> String.replace("$expression", "Aiur.AgentControlCLI.status()")
    |> String.replace("${args%, }", "argv: [\"show\"]")
    |> String.replace("$json_arg", "true")
    |> String.replace("$json", "true")
    |> String.replace("$only_arg", "false")
    |> String.replace("$budget_ms", "1000")
    |> String.replace("$wake_id", "1")
    |> String.replace("$n", "2")
    |> String.replace("$ticket", "\"123\"")
    |> String.replace("$owner", "\"operator\"")
    |> String.replace("$issue", "\"123\"")
    |> String.replace("$message_id", "\"id\"")
    |> String.replace("$encoded", "\"c2FtcGxl\"")
    |> String.replace("${command}", "pause")
    |> String.replace(~r/\$\(\(timeout \* 1000\)\)/, "300000")
    |> String.replace(~r/\$\([^)]*\)/, "\"sample\"")
    |> String.replace(~r/\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/, "\"sample\"")
  end

  defp sample_options(template) do
    cond do
      String.contains?(template, "operator_answer") -> ~s|decision_id: "d", operator: true, option_id: "o", expected_version: 1, confirmation: "d"|
      String.contains?(template, "executor_answer") -> ~s|decision_id: "d", option_id: "o", expected_version: 1, confirmation: "d"|
      String.contains?(template, "executor_escalate") -> ~s|decision_id: "d", expected_version: 1|
      String.contains?(template, "executor_reclassify") -> ~s|decision_id: "d", expected_version: 1, authority: "product"|
      String.contains?(template, "executor_moot") -> ~s|decision_id: "d", expected_version: 1, reason: "done"|
      String.contains?(template, "ticket_estimate") -> "id: 1"
      true -> "json: true"
    end
  end
end
