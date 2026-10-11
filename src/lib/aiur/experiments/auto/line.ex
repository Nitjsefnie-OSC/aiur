defmodule Aiur.Experiments.Auto.Line do
  @moduledoc false
  @enforce_keys [:source, :key, :at]
  defstruct [:source, :key, :at, :before_floor, evidence: %{}]
  @type t :: %__MODULE__{source: atom(), key: String.t(), at: DateTime.t(), evidence: map(), before_floor: DateTime.t() | nil}
end
