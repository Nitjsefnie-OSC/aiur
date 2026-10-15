defmodule Aiur.Experiments.AnalysisTicket do
  @moduledoc false

  @spec render(map(), map()) :: map()
  def render(spec, request) do
    mode = request["mode"]
    title = spec["title"] |> String.replace(~r/[\x00-\x1f\x7f]/u, " ") |> String.slice(0, 190)
    complexity = if request["analysis_type"] == "confirmatory", do: "complexity:3", else: "complexity:2"

    %{
      title: "Analyze experiment: #{title} (#{mode})",
      labels: ["agent:todo", complexity, "experiment-analysis"],
      body: brief(request)
    }
  end

  @spec brief(map()) :: String.t()
  def brief(request) do
    id = request["experiment_id"]
    mode = request["mode"]
    deliverable = if mode == "spec", do: "pre-registration", else: "#{request["analysis_type"]} report"

    """
    <!-- aiur-experiment-analysis request=#{request["request_id"]} nonce=#{request["nonce"]} -->
    Run the `aiur-experiment` skill in **#{mode}** mode for experiment `#{id}`.
    Skill: `.claude/skills/aiur-experiment/SKILL.md`.

    - Request revision: #{request["revision"]}. Re-read the request before submitting; a stronger analysis may supersede this brief.
    - Inputs: `aiur experiments show #{id} --json`, `aiur experiments events #{id} --json`.
    - In spec mode, use only baseline values and sample counts; never read post-period outcomes.
    - In report mode, use `aiur experiments stats #{id} --json` and its pinned snapshot.
    - Deliverable: a stored #{deliverable} via `aiur experiments preregister` or `aiur experiments report submit`, matching this request.
    - No code change and no PR. When submit succeeds, post the summary and stored version in the workpad and move this issue to done; no human review is needed.
    """
  end
end
