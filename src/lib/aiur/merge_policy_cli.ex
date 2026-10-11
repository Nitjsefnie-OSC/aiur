defmodule Aiur.MergePolicyCLI do
  @moduledoc "Merge policy visibility for the local control CLI."

  @spec print() :: :ok
  def print do
    policy = Aiur.MergePolicy.current()
    watch = if policy.main_watch.enabled, do: "on(#{policy.main_watch.on_red})", else: "off"
    labels = if policy.ci == "wait" and policy.full_ci_labels == ["main-fix"], do: "", else: " full_ci=[#{Enum.join(policy.full_ci_labels, ",")}]"
    main = if policy.main_watch.enabled, do: " " <> main_state(Aiur.MainWatch.state()), else: ""
    IO.puts("MERGE POLICY ci=#{policy.ci} local_tests=#{policy.local_tests}#{labels} main_watch=#{watch}#{main}")
  end

  @spec main_state(map()) :: String.t()
  def main_state(%{unavailable: true} = state), do: main_state(Map.delete(state, :unavailable)) <> " (unavailable)"

  def main_state(%{status: :red} = state) do
    since =
      case red_time(Map.get(state, :red_since)) do
        {:ok, time} -> " since " <> Calendar.strftime(time, "%H:%M")
        _ -> ""
      end

    fixer = if state[:fixer_ticket], do: " (##{state.fixer_ticket})", else: ""
    "main=red" <> since <> fixer
  end

  def main_state(%{status: :green}), do: "main=green"
  def main_state(_state), do: "main=unknown"

  defp red_time(value) when is_integer(value), do: DateTime.from_unix(value, :millisecond)
  defp red_time(_value), do: {:error, :invalid_timestamp}
end
