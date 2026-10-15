defmodule Aiur.PostDeployChecklistTest do
  use ExUnit.Case, async: true

  alias Aiur.Events.Exchange
  alias Aiur.PostDeployChecklist

  test "records merged PR checks once and keeps completion across restart" do
    dir = Path.join(System.tmp_dir!(), "post-deploy-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "checks.json")
    exchange = start_supervised!({Exchange, name: nil}, id: :post_deploy_exchange)
    start_supervised!({PostDeployChecklist, name: :post_deploy_test, path: path, exchange: exchange}, id: :post_deploy_test)

    event = %{
      topic: "ticket.42.pr.merged",
      repository: "aiur",
      pr: %{
        "number" => 91,
        "html_url" => "https://github.com/aiur-team/aiur/pull/91",
        "merged_at" => "2026-10-14T12:00:00Z",
        "head" => %{"repo" => %{"full_name" => "aiur-team/aiur"}}
      },
      post_deploy_checks: ["dictate start run and confirm the dashboard shows it (operator: physical Stream Deck)"]
    }

    assert Exchange.publish("ticket.42.pr.merged", event, exchange) == 1
    assert Exchange.publish("ticket.42.pr.merged", event, exchange) == 1
    [check] = PostDeployChecklist.list(:post_deploy_test)
    assert check["text"] == "dictate start run and confirm the dashboard shows it"
    assert check["operator"] == "physical Stream Deck"
    assert check["pr_number"] == 91
    assert check["pr_url"] == "https://github.com/aiur-team/aiur/pull/91"
    assert is_nil(check["done_at"])

    assert :ok = PostDeployChecklist.mark_done(check["id"], "executor", :post_deploy_test)
    assert [%{"done_by" => "executor", "done_at" => done_at}] = PostDeployChecklist.list(:post_deploy_test)
    assert is_binary(done_at)

    stop_supervised!(:post_deploy_test)
    start_supervised!({PostDeployChecklist, name: :post_deploy_recovered, path: path, exchange: exchange}, id: :post_deploy_recovered)
    assert [%{"done_by" => "executor", "text" => "dictate start run and confirm the dashboard shows it"}] = PostDeployChecklist.list(:post_deploy_recovered)

    File.rm_rf!(dir)
  end

  test "ignores merged PRs without post-deploy lines" do
    dir = Path.join(System.tmp_dir!(), "post-deploy-empty-#{System.unique_integer([:positive])}")
    exchange = start_supervised!({Exchange, name: nil}, id: :post_deploy_empty_exchange)
    start_supervised!({PostDeployChecklist, name: :post_deploy_empty, path: Path.join(dir, "checks.json"), exchange: exchange}, id: :post_deploy_empty)

    assert Exchange.publish("ticket.42.pr.closed_unmerged", %{topic: "ticket.42.pr.closed_unmerged", pr: %{"body" => "Post-deploy check: do something"}}, exchange) == 0
    assert :ok = PostDeployChecklist.ingest(%{pr: %{"body" => "## Local tests\n- `mix test` -> passed"}}, :post_deploy_empty)
    assert PostDeployChecklist.list(:post_deploy_empty) == []
    File.rm_rf!(dir)
  end
end
