defmodule Aiur.Events.PostDeployChecks do
  @moduledoc "Extract post-deploy checklist lines from a PR's Local tests section."

  @spec from_pr_body(term()) :: [String.t()]
  def from_pr_body(body) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.reduce({false, []}, fn line, {in_local_tests?, checks} ->
      cond do
        Regex.match?(~r/^\s*##\s+Local tests\s*$/i, line) -> {true, checks}
        Regex.match?(~r/^\s*[#]{1,6}\s+/, line) -> {false, checks}
        in_local_tests? and length(checks) < 20 -> {true, post_deploy_check_line(line) ++ checks}
        in_local_tests? -> {true, checks}
        true -> {false, checks}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  def from_pr_body(_body), do: []

  defp post_deploy_check_line(line) do
    case Regex.run(~r/^\s*(?:[-*]\s*)?Post-deploy check:\s*(\S.*)$/i, String.trim(line)) do
      [_, text] -> [String.slice(text, 0, 2_000)]
      _ -> []
    end
  end
end
