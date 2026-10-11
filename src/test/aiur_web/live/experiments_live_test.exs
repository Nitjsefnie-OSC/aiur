defmodule AiurWeb.ExperimentsLiveTest do
  use Aiur.TestSupport
  import Phoenix.ConnTest, except: [build_conn: 0]
  import Phoenix.LiveViewTest
  alias AiurWeb.Endpoint
  @endpoint Endpoint

  defmodule Facade do
    def status, do: Application.fetch_env!(:aiur, :experiment_live_fixture).status
    def list, do: Application.fetch_env!(:aiur, :experiment_live_fixture).list
    def fetch(id), do: Map.get(Application.fetch_env!(:aiur, :experiment_live_fixture).details, id, {:error, :not_found})
    def subscribe, do: Phoenix.PubSub.subscribe(Aiur.PubSub, "experiment-live-test")
  end

  setup do
    previous = Map.new([:experiments_facade, :experiment_live_fixture, Endpoint], &{&1, Application.get_env(:aiur, &1)})
    Application.put_env(:aiur, :experiments_facade, Facade)
    Application.put_env(:aiur, Endpoint, Keyword.merge(previous[Endpoint] || [], server: false, dashboard_auth_required: false, secret_key_base: String.duplicate("s", 64)))
    fixture()
    Aiur.TestSupport.start_owned_endpoint!()
    on_exit(fn -> for {key, value} <- previous, do: restore(key, value) end)
    :ok
  end

  test "empty store names creation paths without chart frames" do
    {:ok, view, html} = live(build_conn(), "/experiments")
    assert has_element?(view, "[data-empty-reason=no_experiments]")
    assert html =~ "version bump or release"
    assert html =~ "tagged feature epic merge"
    assert html =~ "analyst request"
    refute has_element?(view, "#exp-charts")
  end

  test "disabled and unreadable stores remain distinct and never expose paths" do
    for {reason, state, copy} <- [{:disabled, "component_off", "Experiments are not enabled"}, {{:bad, "/private/store"}, "store_unreadable", "could not be read"}] do
      fixture(status: %{available?: false, store: {:error, reason}, capture: :on})
      {:ok, view, html} = live(build_conn(), "/experiments")
      assert has_element?(view, "[data-empty-reason=#{state}]")
      assert html =~ copy
      refute html =~ "/private/store"
    end
  end

  test "capture off still renders specification and unavailable evidence" do
    populated()
    {:ok, view, html} = live(build_conn(), "/experiments/first")
    assert has_element?(view, "#experiments-capture-off")
    assert has_element?(view, ".exp-index a[aria-current=page]", "First")
    assert html =~ "A registered hypothesis"
    assert html =~ "Evidence unavailable"
    refute html =~ "Frozen baseline</dt><dd>0"
    assert html =~ "delivery-speed/start_to_merge"
    assert has_element?(view, "#exp-charts")
    assert has_element?(view, "#exp-report")
  end

  test "index chooses first detail without changing the mobile index URL" do
    populated()
    {:ok, view, _html} = live(build_conn(), "/experiments")
    assert has_element?(view, "#experiments-page[data-selection=index]")
    assert has_element?(view, "#exp-detail h2", "First")
    render_click(element(view, ".exp-index a", "Second"))
    assert_patch(view, "/experiments/second")
    assert has_element?(view, "#exp-detail h2", "Second")
    assert has_element?(view, "#experiments-page[data-selection=detail]")
    render_click(element(view, ".exp-back"))
    assert_patch(view, "/experiments")
  end

  test "unknown id has a shell state and link back" do
    populated()
    {:ok, view, _html} = live(build_conn(), "/experiments/missing")
    assert has_element?(view, "[data-empty-reason=not_found]", "Experiment not found")
    assert has_element?(view, "[data-empty-reason=not_found] a[href='/experiments']")
  end

  test "facade notifications refresh index and open detail, unrelated messages do not" do
    populated()
    {:ok, view, _html} = live(build_conn(), "/experiments/first")
    populated("Changed hypothesis")
    send(view.pid, :irrelevant)
    assert render(view) =~ "A registered hypothesis"
    send(view.pid, {:experiments_changed, "second"})
    assert render(view) =~ "A registered hypothesis"
    Phoenix.PubSub.broadcast(Aiur.PubSub, "experiment-live-test", {:experiments_changed, "first"})
    assert render(view) =~ "Changed hypothesis"
    fixture()
    send(view.pid, {:experiments_changed, :all})
    assert has_element?(view, "[data-empty-reason=no_experiments]")
    refute has_element?(view, "#exp-detail")
  end

  defp fixture(opts \\ []) do
    Application.put_env(:aiur, :experiment_live_fixture, Map.merge(%{status: %{available?: true, store: :ok, capture: :off}, list: {:ok, []}, details: %{}}, Map.new(opts)))
  end

  defp populated(hypothesis \\ "A registered hypothesis") do
    spec = "test/aiur/experiments/fixtures/valid_line.json" |> File.read!() |> Jason.decode!() |> Map.fetch!("spec")
    summaries = for {id, title} <- [{"first", "First"}, {"second", "Second"}], do: %{id: id, title: title, status: "active", created_at: "2026-10-09T00:00:00Z"}
    details = Map.new(summaries, fn row -> {row.id, {:ok, %{spec: Map.merge(spec, %{"id" => row.id, "title" => row.title, "hypothesis" => hypothesis}), phase: :collecting}}} end)
    fixture(list: {:ok, summaries}, details: details)
  end

  defp build_conn, do: Phoenix.ConnTest.build_conn() |> Plug.Conn.put_req_header("authorization", "Basic " <> Base.encode64("operator:test-dashboard-secret"))

  defp restore(key, nil), do: Application.delete_env(:aiur, key)
  defp restore(key, value), do: Application.put_env(:aiur, key, value)
end
