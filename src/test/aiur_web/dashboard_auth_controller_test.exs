defmodule AiurWeb.DashboardAuthControllerTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias AiurWeb.DashboardAuth.{ChallengeStore, Passkeys}
  alias AiurWeb.{DashboardAuthController, FinancialDataAccess}

  @session_options Plug.Session.init(store: :cookie, key: "_aiur_auth_test", signing_salt: "aiur-auth-test")

  setup do
    previous_workflow_override = Process.get(:workflow_file_path_override)
    config_dir = Aiur.TestSupport.tmp_root!("dashboard-auth-controller")
    File.mkdir_p!(config_dir)
    config_path = Path.join(config_dir, "config")
    :ok = Aiur.TestSupport.write_workflow_file!(config_path)
    original = File.read!(config_path)

    config =
      if String.contains?(original, "\nserver:\n") do
        String.replace(original, "\nserver:\n", "\nserver:\n  public_url: https://aiur.example.test:4001\n", global: false)
      else
        original <> "\nserver:\n  public_url: https://aiur.example.test:4001\n"
      end

    File.write!(config_path, config <> "\ndashboard_auth:\n  passkeys: true\n  google:\n    allowed_emails: [operator@example.test]\n")
    Process.put(:workflow_file_path_override, config_path)

    on_exit(fn ->
      if previous_workflow_override do
        Process.put(:workflow_file_path_override, previous_workflow_override)
      else
        Process.delete(:workflow_file_path_override)
      end

      Aiur.TestCleanup.rm_rf!(config_dir)
      FinancialDataAccess.Generation.invalidate()
    end)

    :ok
  end

  test "passkey enrollment challenge refuses a session without recent Google authentication" do
    conn = DashboardAuthController.registration_challenge(session_conn(), %{})

    assert conn.status == 403
    assert Jason.decode!(conn.resp_body) == %{"error" => "fresh Google sign-in required"}
    assert get_session(conn, :passkey_registration_challenge) == nil
  end

  test "verified email outside the configured allowlist is refused without a marker" do
    user = %{"email" => "intruder@example.test", "email_verified" => true}
    conn = DashboardAuthController.complete_google_sign_in(session_conn(), user)

    assert conn.status == 401
    assert get_session(conn, FinancialDataAccess.session_key()) == nil
  end

  test "authentication finish consumes its challenge before refusing a replay" do
    assert Passkeys.enabled?()
    challenge = Wax.new_authentication_challenge(origin: "https://aiur.example.test:4001", rp_id: "aiur.example.test")
    assert {:ok, challenge_id} = ChallengeStore.put(challenge)
    conn = put_session(session_conn(), :passkey_authentication_challenge, challenge_id)

    first = DashboardAuthController.authentication_finish(conn, %{"assertion" => %{"rawId" => "invalid"}})
    replay_conn = put_session(session_conn(), :passkey_authentication_challenge, challenge_id)
    replay = DashboardAuthController.authentication_finish(replay_conn, %{"assertion" => %{"rawId" => "invalid"}})

    assert first.status == 401
    assert replay.status == 401
    assert {:error, :challenge_missing_or_replayed} = Passkeys.take_challenge(challenge_id)
    assert get_session(replay, FinancialDataAccess.session_key()) == nil
  end

  defp session_conn do
    :post
    |> conn("/auth")
    |> Map.put(:secret_key_base, String.duplicate("s", 64))
    |> Plug.Session.call(@session_options)
    |> fetch_session()
  end
end
