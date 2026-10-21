defmodule AiurWeb.OperatorControlCenter.MeterStyles do
  @moduledoc "Usage-meter threshold styles shared by summary rows."

  @spec meter_class(number() | nil, number() | nil, number() | nil) :: String.t()
  def meter_class(percent, caution_threshold \\ nil, warning_threshold \\ nil)
  def meter_class(percent, _caution, _warning) when is_number(percent) and percent >= 90, do: "is-critical"

  def meter_class(percent, _caution, warning)
      when is_number(percent) and is_number(warning) and percent >= warning and percent < 90,
      do: "is-warning"

  def meter_class(percent, caution, _warning)
      when is_number(percent) and is_number(caution) and percent >= caution and percent < 90,
      do: "is-caution"

  def meter_class(_percent, _caution, _warning), do: ""
end
