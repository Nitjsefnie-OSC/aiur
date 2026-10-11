defmodule Aiur.Experiments.Auto do
  @moduledoc "Automatic experiment line sources and deploy evidence."
  use Supervisor

  alias Aiur.Experiments.Auto.DeployLedger

  @spec child_specs(keyword()) :: [Supervisor.child_spec() | {module(), keyword()}]
  def child_specs(opts \\ []) do
    config = Keyword.get_lazy(opts, :config, &settings/0)
    if Keyword.get(opts, :recording?, true) and config.enabled, do: [{__MODULE__, opts}], else: []
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @impl true
  def init(opts), do: Supervisor.init([{DeployLedger, Keyword.get(opts, :ledger_opts, [])}], strategy: :one_for_one)

  @spec status() :: map()
  def status do
    %{enabled: settings().enabled, sources: [], deploy_ledger: not is_nil(Process.whereis(DeployLedger))}
  end

  @spec previous_deploy(keyword()) :: {:ok, map() | nil} | {:error, term()}
  def previous_deploy(opts \\ []), do: DeployLedger.previous(opts)

  @spec deploys({DateTime.t(), DateTime.t()}, keyword()) :: {:ok, [map()]} | {:error, term()}
  def deploys(range, opts \\ []), do: DeployLedger.list(range, opts)

  defp settings do
    case Aiur.Config.settings() do
      {:ok, %{experiments: %{enabled: false, auto: auto}}} -> %{auto | enabled: false}
      {:ok, %{experiments: %{auto: auto}}} -> auto
      _unconfigured -> %Aiur.Config.Schema.Experiments.Auto{}
    end
  end
end
