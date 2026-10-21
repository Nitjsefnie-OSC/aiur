defmodule Aiur.HttpServerSecretTest do
  use ExUnit.Case, async: false
  import Bitwise

  alias Aiur.TestCleanup
  alias Plug.Session.COOKIE, as: SessionCookie
  alias Plug.Test

  test "persistent secret file keeps its key across simulated restarts and is private" do
    root = Path.join(System.tmp_dir!(), "aiur-secret-test-#{System.unique_integer([:positive])}")
    old_instance = System.get_env("AIUR_INSTANCE_KEY")
    old_secret = System.get_env("AIUR_SECRET_KEY_BASE")
    old_root = Application.get_env(:aiur, :dashboard_secret_root)
    Application.put_env(:aiur, :dashboard_secret_root, root)
    System.put_env("AIUR_INSTANCE_KEY", "secret-test")
    System.delete_env("AIUR_SECRET_KEY_BASE")

    on_exit(fn ->
      restore_env("AIUR_INSTANCE_KEY", old_instance)
      restore_env("AIUR_SECRET_KEY_BASE", old_secret)
      if old_root, do: Application.put_env(:aiur, :dashboard_secret_root, old_root), else: Application.delete_env(:aiur, :dashboard_secret_root)
      TestCleanup.rm_rf!(root)
    end)

    first = Aiur.HttpServer.secret_key_base_for_test()
    # Simulate a fresh process by fetching the persisted key again and decode
    # a cookie serialized by the previous process with Plug's cookie store.
    second = Aiur.HttpServer.secret_key_base_for_test()
    path = Path.join([root, "instances", "secret-test", "secret_key_base"])
    options = SessionCookie.init(key: "_aiur_key", signing_salt: "aiur-session", encryption_salt: "aiur-session-encryption")
    old_conn = Test.conn(:get, "/") |> Map.put(:secret_key_base, first)
    cookie = SessionCookie.put(old_conn, nil, %{"marker" => "survives"}, options)
    new_conn = Test.conn(:get, "/") |> Map.put(:secret_key_base, second)

    assert byte_size(first) >= 64
    assert second == first
    assert {:term, %{"marker" => "survives"}} = SessionCookie.get(new_conn, cookie, options)
    assert (File.stat!(path).mode &&& 0o777) == 0o600
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
