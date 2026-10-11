defmodule Aiur.PrMerge.Gate do
  @moduledoc false
  @attribution ["co-authored-by: claude", "generated with [claude", "claude-session", "claude.ai/code/session"]

  @spec refusals(map(), map(), map()) :: [String.t()]
  def refusals(pr, policy, opts) do
    []
    |> reject(pr.head != opts.reviewed_sha, "head moved: reviewed #{opts.reviewed_sha}, current #{pr.head}")
    |> reject(pr.draft, "draft PR")
    |> reject(pr.state != "OPEN", "PR is not open")
    |> reject(pr.conflict, "conflict")
    |> reject(not (pr.approved or pr.bypass or opts.approve_body != nil), "approval or verified bypass identity required")
    |> Kernel.++(Enum.map(pr.failed, &"CI failed: #{&1}"))
    |> Kernel.++(Enum.map(opts.inherited, &"inherited failure not verified by base watcher: #{&1}"))
    |> Kernel.++(pending_refusals(pr, policy))
    |> Kernel.++(attribution(pr, policy))
  end

  @spec pending(map()) :: [String.t()]
  def pending(pr), do: Enum.uniq(pr.required -- pr.passed)

  defp pending_refusals(pr, policy) do
    if pending(pr) == [] do
      []
    else
      []
      |> reject(policy.ci != "pending_ok", "waiting for CI (policy ci=#{policy.ci})")
      |> reject(pr.full_ci, "full CI required (labels or changed paths)")
      |> Kernel.++(evidence(pr, policy))
    end
  end

  defp evidence(pr, %{ci: "pending_ok"} = policy) do
    with true <- policy.local_tests != "none" and policy.main_watch.enabled,
         {:ok, evidence} <- Aiur.LocalTestEvidence.parse(pr.body),
         :ok <- Aiur.LocalTestEvidence.validate(evidence, policy.local_tests, pr.head) do
      []
    else
      _ -> ["no local-test evidence for #{pr.head}; wait for CI"]
    end
  end

  defp evidence(_pr, _policy), do: []

  defp attribution(pr, %{attribution_scan: true}) do
    text = String.downcase(pr.title <> "\n" <> pr.body)
    for pattern <- @attribution, String.contains?(text, pattern), do: "attribution scan: #{pattern}"
  end

  defp attribution(_pr, _policy), do: []
  defp reject(reasons, true, reason), do: reasons ++ [reason]
  defp reject(reasons, false, _reason), do: reasons
end
