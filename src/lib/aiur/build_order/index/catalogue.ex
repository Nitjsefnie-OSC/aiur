defmodule Aiur.BuildOrder.Index.Catalogue do
  @moduledoc false
  alias Aiur.BuildOrder.{Epic, FeatureStats, SourceFreshness}

  @spec general(map()) :: {:ok, list()} | {:error, :epic_config_unavailable}
  def general(%{settings: {:ok, %{build_order: %{general_epics: general}}}}) when is_list(general), do: {:ok, general}
  def general(_), do: {:error, :epic_config_unavailable}

  @spec registry(map()) :: map() | :unknown
  def registry(%{features: {:ok, registry}}), do: registry
  def registry(_), do: :unknown

  @spec build(map(), list(), map(), integer()) :: map()
  def build(parts, general, rows, now) do
    registry = registry(parts)
    features = if registry == :unknown, do: %{}, else: registry.features
    sorted = Enum.sort_by(features, fn {slug, f} -> {SourceFreshness.ms(f.from) || :unknown, slug} end)
    facts = Map.new(rows, fn {_id, row} -> {row.num, fact(parts, row)} end)
    stats = if registry == :unknown, do: %{}, else: FeatureStats.compute_all(registry, facts, now: now)

    features =
      Map.new(sorted, fn {slug, f} ->
        {slug, %{key: slug, label: f.label, hue: f.hue, epics: Enum.map(f.epics, & &1.key), from: SourceFreshness.ms(f.from), to: SourceFreshness.ms(f.to), stats: FeatureStats.to_json(stats[slug])}}
      end)

    epics = Map.new(general, fn e -> {e.key, e |> Map.take([:key, :label, :hue, :icon]) |> Map.put(:general, true)} end)
    feature_epics = for {slug, f} <- sorted, e <- f.epics, into: %{}, do: {e.key, %{key: e.key, label: e.label, hue: f.hue, icon: "layers", feature: slug, temp: true}}
    order = Enum.map(general, & &1.key) ++ Enum.flat_map(sorted, fn {_, f} -> Enum.map(f.epics, & &1.key) end) ++ ["unsorted"]
    %{features: features, epics: epics |> Map.merge(feature_epics) |> Map.put("unsorted", Epic.unsorted()), order: order}
  end

  defp fact(parts, row) do
    historic =
      case parts[:history] do
        {:ok, %{rows: rows}} -> Map.get(rows, row.num, :missing)
        _ -> :missing
      end

    progress = if is_integer(row.pct), do: {:known, row.pct}, else: {:unknown, :progress}
    FeatureStats.fact(historic, String.to_existing_atom(row.status), progress)
  end
end
