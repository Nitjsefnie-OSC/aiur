defmodule AiurWeb.OperatorControlCenterComponentsBuildOrderStatusTest do
  use Aiur.TestSupport

  alias Aiur.BuildOrder.{Diagnostic, ProviderHealth}

  import AiurWeb.OperatorControlCenterComponentsFixtures

  test "a fetched malformed Build Order renders one structural-failure state with its observed count" do
    html =
      render_selected(%{
        unresolved_model(:structurally_invalid)
        | summary: resolved_summary(),
          diagnostics: [Diagnostic.new(:invalid_root)]
      })

    {:ok, document} = Floki.parse_document(html)

    assert [_card] = Floki.find(document, ".bo-state-card")
    assert html =~ "The plan is unreadable"
    assert html =~ "Investigate why Build Order #1567&#39;s plan is unreadable."
    assert html =~ "`invalid_root`"
    assert html =~ "`members: 0`"
    refute html =~ "Build Order graph summary"
    refute html =~ "Unresolved"
    refute html =~ "Plan distribution"
    refute html =~ ">Analytics<"
    refute html =~ "Usage and cost"
    refute html =~ "Root data is unavailable"
  end

  test "a malformed Build Order with no structural diagnostic falls back to the structural verdict" do
    html = render_selected(%{unresolved_model(:structurally_invalid) | summary: resolved_summary()})

    assert html =~ "The plan is unreadable"
    assert html =~ "`structurally_invalid`"
  end

  test "a malformed Build Order never reports its provider health failure as the structural fault" do
    html =
      render_selected(%{
        unresolved_model(:structurally_invalid)
        | summary: resolved_summary(),
          planning_health: %ProviderHealth{generation: 9, state: :unavailable, failure: :rate_limited},
          diagnostics: [Diagnostic.new(:duplicate_identity)]
      })

    {:ok, document} = Floki.parse_document(html)

    assert [card] = Floki.find(document, ".bo-state-card")
    card_text = Floki.text(card)

    assert html =~ "The plan is unreadable"
    # The code shown is the observed structural defect, not the fetch fault.
    assert card_text =~ "Reported fault: duplicate_identity"
    assert html =~ "The selected-root provider reports `duplicate_identity`"
    refute card_text =~ "rate_limited"
  end

  test "a malformed Build Order still reports a concurrent provider outage" do
    html =
      render_selected(%{
        unresolved_model(:structurally_invalid)
        | summary: resolved_summary(),
          diagnostics: [Diagnostic.new(:duplicate_identity), Diagnostic.new(:provider_unavailable)]
      })

    assert html =~ "The selected-root provider reports `duplicate_identity`"
    assert html =~ "also reported: `provider_unavailable`"
  end

  test "a malformed Build Order with unresolved counts adds no restated observation" do
    html = render_selected(%{unresolved_model(:structurally_invalid) | diagnostics: [Diagnostic.new(:invalid_root)]})

    assert html =~ "The selected-root provider reports `invalid_root`."
    refute html =~ "the fetched response failed structural validation"
  end

  test "the single failure state names the specific reported fault, not a generic outage" do
    html =
      render_selected(%{
        unresolved_model(:provider_unavailable)
        | planning_health: %ProviderHealth{generation: 9, state: :unavailable, failure: :rate_limited}
      })

    {:ok, document} = Floki.parse_document(html)

    assert [_card] = Floki.find(document, ".bo-state-card")
    assert html =~ "Reported fault:"
    assert html =~ "`rate_limited`"
    refute html =~ "provider_unavailable"
  end

  test "the single failure state still reports genuinely distinct faults" do
    html =
      render_selected(%{
        unresolved_model(:provider_unavailable)
        | planning_health: %ProviderHealth{generation: 9, state: :unavailable, failure: :rate_limited},
          diagnostics: [Diagnostic.new(:provider_unavailable), Diagnostic.new(:pagination_mismatch)]
      })

    {:ok, document} = Floki.parse_document(html)

    assert [_card] = Floki.find(document, ".bo-state-card")
    assert html =~ "also reported: `pagination_mismatch`"
    # `provider_unavailable` here restates the reported fault rather than adding one.
    refute html =~ "provider_unavailable"
  end

  test "a saved plan dates itself and marks its percentages as of then" do
    saved_at = ~U[2026-08-10 06:22:11Z]

    html =
      render_selected(%{
        sample_view_model()
        | status: :provider_stale,
          summary: resolved_summary(),
          planning_health: %ProviderHealth{generation: 9, state: :stale, last_success_at: saved_at}
      })

    # The state card says how old the plan is, not merely that it is saved.
    assert html =~ "Showing the last saved plan, read 5h 37m ago."
    assert html =~ "The counts and percentages below are as of then, not now."

    {:ok, document} = Floki.parse_document(html)
    assert [head] = Floki.find(document, ".bo-waves-head")

    # The wave percentages carry the same dateline and the same age, so the two
    # cannot drift into separate accounts of the same moment.
    assert Floki.attribute([head], "class") == ["bo-waves-head is-stale"]
    assert Floki.attribute([head], "aria-label") == ["Wave completion as of the last saved plan"]
    assert Floki.text(head) =~ "As of 06:22:11Z (5h 37m ago) — not current"
    assert Floki.attribute(Floki.find(head, "time"), "datetime") == ["2026-08-10T06:22:11Z"]
  end

  test "a saved plan with no recorded read time still disclaims its percentages" do
    html =
      render_selected(%{
        sample_view_model()
        | status: :provider_stale,
          summary: resolved_summary(),
          planning_health: %ProviderHealth{generation: 9, state: :stale, last_success_at: nil}
      })

    assert html =~ "Showing the last saved plan. The counts and percentages below are as of when it was read, not now."
    # The percentages are just as stale without a read time, so they are marked
    # all the same; only the dateline has nothing to name.
    assert html =~ "is-stale"
    assert html =~ "Wave completion as of the last saved plan"
    assert html =~ "As of an unrecorded read — not current"
  end

  test "a current plan carries no dateline and no stale marking" do
    html =
      render_selected(%{
        sample_view_model()
        | summary: resolved_summary(),
          planning_health: %ProviderHealth{generation: 9, state: :healthy, last_success_at: ~U[2026-08-10 06:22:11Z]}
      })

    refute html =~ "is-stale"
    refute html =~ "not current"
    refute html =~ "last saved plan"
  end
end
