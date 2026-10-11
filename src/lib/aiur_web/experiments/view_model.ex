defmodule AiurWeb.Experiments.ViewModel do
  @moduledoc "Experiment metadata formatted for display, without computing statistical evidence."

  @spec index_item(map(), map()) :: map()
  def index_item(summary, detail) do
    spec = Map.get(detail, :spec, %{})

    %{
      id: summary.id,
      title: Map.get(summary, :title) || summary.id,
      kind_label: kind_label(Map.get(spec, "design")),
      status: Map.get(summary, :status) || "unknown",
      phase: Map.get(detail, :phase, :unknown),
      created_at: Map.get(summary, :created_at),
      metrics: [],
      labels: [],
      evidence_state: :pending
    }
  end

  @spec detail(map()) :: map()
  def detail(detail) do
    spec = Map.get(detail, :spec, %{})
    summary = Map.new(~w(id title status created_at)a, &{&1, Map.get(spec, Atom.to_string(&1))})

    Map.merge(index_item(summary, detail), %{
      hypothesis: Map.get(spec, "hypothesis", ""),
      design: Map.get(spec, "design"),
      windows: Map.get(spec, "windows", %{}),
      window_labels: window_labels(Map.get(spec, "windows", %{})),
      design_summary: design_summary(Map.get(spec, "design")),
      metric_specs: Map.get(spec, "metrics", []),
      min_samples: Map.get(spec, "min_samples"),
      frozen_baseline: :unknown,
      annotations: Map.get(detail, :annotations, []),
      read_only?: Map.get(detail, :read_only?, false)
    })
  end

  @spec order([map()]) :: [map()]
  def order(items) do
    Enum.sort_by(items, fn item ->
      {if(item.status in ["collecting", "active"], do: 0, else: 1), -timestamp(item.created_at), item.id}
    end)
  end

  defp kind_label(%{"kind" => "before_after"}), do: "Before/after"

  defp kind_label(%{"kind" => "ab", "cohorts" => cohorts}) when is_list(cohorts) do
    case length(cohorts) do
      2 -> "A/B"
      3 -> "A/B/C"
      4 -> "A/B/C/D"
      count -> "#{count} cohorts"
    end
  end

  defp kind_label(_design), do: "Unknown design"

  defp design_summary(%{"kind" => "before_after", "change" => change}) when is_map(change),
    do: "#{change["ref"] || "Unknown change"} · #{change["time"] || "Unknown time"}"

  defp design_summary(%{"kind" => "ab", "cohorts" => cohorts}) when is_list(cohorts),
    do: Enum.map_join(cohorts, " · ", &Map.get(&1, "label", "Unknown cohort"))

  defp design_summary(_design), do: "Unknown design"

  defp window_labels(windows) when is_map(windows) do
    for key <- ~w(before after observation), is_map(windows[key]) do
      %{label: String.capitalize(key), text: "#{windows[key]["start"] || "Unknown start"} → #{windows[key]["end"] || "Open"}"}
    end
  end

  defp window_labels(_windows), do: []

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _offset} -> DateTime.to_unix(time, :microsecond)
      {:error, _reason} -> 0
    end
  end

  defp timestamp(_value), do: 0
end
