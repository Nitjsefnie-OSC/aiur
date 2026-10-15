defmodule Aiur.TestRunIsolation do
  @moduledoc false

  @spec scope_root() :: {:ok, Path.t()} | {:error, :missing_test_state_dir} | :ordinary
  def scope_root do
    case {System.get_env("AIUR_DEV_TEST_TICKET_IDS"), System.get_env("AIUR_DEV_TEST_STATE_DIR")} do
      {scope, root} when is_binary(scope) and scope != "" and is_binary(root) and root != "" -> {:ok, root}
      {scope, _root} when is_binary(scope) and scope != "" -> {:error, :missing_test_state_dir}
      _ -> :ordinary
    end
  end

  @spec decision_state_override(String.t() | nil) :: {:ok, String.t()} | {:error, atom()} | :resolve
  def decision_state_override(configured_path) do
    case scope_root() do
      {:ok, _root} -> :resolve
      {:error, reason} -> {:error, reason}
      :ordinary -> configured_override(configured_path)
    end
  end

  @spec decision_state_root(Path.t()) :: Path.t()
  def decision_state_root(fallback) do
    case scope_root() do
      {:ok, root} ->
        root

      _ ->
        case System.get_env("AIUR_BG_STATE_DIR") do
          root when is_binary(root) and root != "" -> root
          _ -> fallback
        end
    end
  end

  @spec remote_github_budget_exports() :: String.t()
  def remote_github_budget_exports do
    case {System.get_env("AIUR_DEV_TEST_TICKET_IDS"), System.get_env("AIUR_DEV_TEST_RUN_ID")} do
      {scope, run_id} when is_binary(scope) and scope != "" ->
        run_id =
          if is_binary(run_id) and Regex.match?(~r/\Aaiur-test-budget\.[A-Za-z0-9_-]+\z/, run_id),
            do: run_id,
            else: "unbound-#{System.unique_integer([:positive])}"

        "export AIUR_GITHUB_BUDGET_ROOT=\"$HOME/.aiur/test-sandboxes/#{run_id}/github-budget\"\n" <>
          "export AIUR_GITHUB_CREDENTIAL_FILE=\"$AIUR_GITHUB_BUDGET_ROOT/agent-token\"\n"

      _ordinary_run ->
        "export AIUR_GITHUB_BUDGET_ROOT='~/.aiur/github-budget'\n" <>
          "AIUR_GITHUB_BUDGET_ROOT=\"$HOME/${AIUR_GITHUB_BUDGET_ROOT#\\~/}\"\nexport AIUR_GITHUB_BUDGET_ROOT\n" <>
          "export AIUR_GITHUB_CREDENTIAL_FILE='~/.aiur/github-budget/agent-token'\n" <>
          "AIUR_GITHUB_CREDENTIAL_FILE=\"$HOME/${AIUR_GITHUB_CREDENTIAL_FILE#\\~/}\"\nexport AIUR_GITHUB_CREDENTIAL_FILE\n"
    end
  end

  defp configured_override(path) when is_binary(path) and path != "", do: {:ok, path}
  defp configured_override(_path), do: :resolve
end
