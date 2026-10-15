defmodule Aiur.Config.Schema.GitIdentity do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # Unset fields fall back to the `tracker.github.bot_account` login; see
    # `Aiur.AgentEnvironment.GitIdentity`.
    # @config-reference config-configuration-agent-00 agent.git_identity.name
    # @config-detail agent.git_identity.name | string or nil | nil | Commit author and committer name for agent workspaces. |
    # @config-reference config-configuration-agent-00 agent.git_identity.email
    # @config-detail agent.git_identity.email | string or nil | nil | Commit author and committer email for agent workspaces. |
    field(:name, :string)
    field(:email, :string)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:name, :email])
    # Both values travel in environment variables and a shell export prefix.
    |> validate_format(:name, ~r/\A[^\r\n<>]+\z/)
    |> validate_format(:email, ~r/\A[^\s<>]+@[^\s<>]+\z/)
  end
end
