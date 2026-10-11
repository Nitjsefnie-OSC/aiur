defmodule Aiur.BrowserHarness.ExperimentsFixture do
  @moduledoc false
  import Plug.Conn
  alias Aiur.Experiments.Spec

  @fixtures Path.expand("../../aiur/experiments/fixtures", __DIR__)
  @root Path.join(System.tmp_dir!(), "browser-experiments-#{Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)}")

  def init(opts), do: opts
  def call(conn, _opts), do: configure(conn, conn.params)

  def configure(conn, %{"scenario" => scenario}) when scenario in ~w(empty mixed) do
    prepare(scenario)
    Phoenix.PubSub.broadcast(Aiur.PubSub, "experiments", {:experiments_changed, :all})
    conn |> put_resp_header("location", "/experiments") |> send_resp(302, "")
  end

  def configure(conn, _params), do: send_resp(conn, 400, "Unknown experiments fixture scenario")

  def prepare(scenario) do
    root = Path.join(@root, scenario)
    File.mkdir_p!(root)

    if scenario == "mixed" do
      write_spec(root, "valid_line", "release-speed", "Release delivery speed", "2026-10-09T00:00:00Z")
      write_spec(root, "valid_ab", "cohort-speed", "Cohort delivery speed", "2026-10-08T00:00:00Z")
    end

    Application.put_env(:aiur, :experiments_dir, root)
  end

  defp write_spec(root, fixture, id, title, created_at) do
    spec =
      Path.join(@fixtures, fixture <> ".json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("spec")
      |> Map.merge(%{"id" => id, "title" => title, "created_at" => created_at})

    {:ok, validated} = Spec.new(spec)
    directory = Path.join(root, id)
    File.mkdir_p!(directory)
    File.write!(Path.join(directory, "spec.json"), Jason.encode!(Spec.to_map(validated)))
    File.write!(Path.join(directory, "journal.ndjson"), "")
    File.write!(Path.join(directory, "annotations.ndjson"), "")
  end
end
