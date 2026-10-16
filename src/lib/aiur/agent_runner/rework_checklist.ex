defmodule Aiur.AgentRunner.ReworkChecklist do
  @moduledoc false

  @spec validate([map()], term(), String.t() | nil, [String.t()], [String.t()]) ::
          :allow | {:blocked, [String.t()]}
  def validate(findings, checklist, dispatch_head, commits, touched) do
    case precondition(findings, checklist, dispatch_head, commits) do
      :validate -> validate_items(findings, checklist, commits, touched)
      result -> result
    end
  end

  defp precondition([], checklist, head, commits) when checklist in [nil, []] do
    cond do
      not is_binary(head) or head in ["", :pending, :lookup_failed] ->
        {:blocked, ["review head is unavailable; cannot verify new commits"]}

      commits == [] ->
        {:blocked, ["no new commits since the review"]}

      true ->
        :allow
    end
  end

  defp precondition([], _checklist, _head, _commits),
    do: {:blocked, ["checklist claims findings but GitHub has no open review findings"]}

  defp precondition(_findings, checklist, _head, _commits)
       when not is_list(checklist) or checklist == [],
       do: {:blocked, ["review findings checklist is missing"]}

  defp precondition(_findings, _checklist, head, _commits)
       when not is_binary(head) or head in ["", :pending, :lookup_failed],
       do: {:blocked, ["review head is unavailable; cannot verify new commits"]}

  defp precondition(_findings, _checklist, _head, []),
    do: {:blocked, ["no new commits since the review"]}

  defp precondition(_findings, _checklist, _head, _commits), do: :validate

  defp validate_items(findings, checklist, commits, touched) do
    expected =
      findings
      |> Enum.map(&value(&1, "id", "databaseId"))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    supplied =
      checklist
      |> Enum.map(&value(&1, "id"))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> MapSet.new()

    missing = MapSet.difference(expected, supplied)

    invalid = Enum.filter(checklist, &(value(&1, "status") not in ["fixed", "disputed"]))

    unsupported_dispute =
      Enum.filter(
        checklist,
        &(value(&1, "status") == "disputed" and blank?(value(&1, "evidence")))
      )

    invalid_commit =
      Enum.filter(
        checklist,
        &(value(&1, "status") == "fixed" and value(&1, "commit") not in commits)
      )

    untouched =
      Enum.filter(
        checklist,
        &(value(&1, "status") == "fixed" and value(&1, "file") not in touched)
      )

    reasons =
      Enum.map(missing, &"finding #{&1} is unchecked") ++
        Enum.map(invalid, &"finding #{value(&1, "id") || "?"} must be fixed or disputed") ++
        Enum.map(unsupported_dispute, &"finding #{value(&1, "id") || "?"} disputed without evidence") ++
        Enum.map(
          invalid_commit,
          &"finding #{value(&1, "id") || "?"} marked fixed without a new commit"
        ) ++
        Enum.map(
          untouched,
          &"finding #{value(&1, "id") || "?"} marked fixed but its file was not touched"
        )

    if reasons == [], do: :allow, else: {:blocked, reasons}
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: true

  defp value(map, key, fallback \\ nil) do
    atom_key = String.to_existing_atom(key)

    Map.get(map, key) || Map.get(map, atom_key) ||
      if(fallback, do: Map.get(map, fallback), else: nil)
  end
end
