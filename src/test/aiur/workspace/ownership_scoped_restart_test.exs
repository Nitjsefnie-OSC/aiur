defmodule Aiur.Workspace.OwnershipScopedRestartTest do
  use Aiur.TestSupport

  # #4736: under a partial ticket scope the Store's restart cannot resolve its
  # decision-state path, the supervisor gives up, and later tests see
  # `unknown registry: Aiur.Workspace.Ownership.Registry`.
  test "a child crash under the test ticket scope restarts the ownership registry" do
    Aiur.TestScopeGuard.put_ticket_scope!("99")
    prior = Process.whereis(Aiur.Workspace.Ownership.Store)
    assert is_pid(prior)

    Process.exit(prior, :kill)

    assert {:ok, _store} = Aiur.TestSupport.await_supervised_restart(Aiur.Workspace.Ownership.Store, prior)
    assert Registry.lookup(Aiur.Workspace.Ownership.Registry, "99") == []
  end
end
