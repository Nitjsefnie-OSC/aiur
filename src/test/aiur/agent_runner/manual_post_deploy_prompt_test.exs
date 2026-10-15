defmodule Aiur.AgentRunner.ManualPostDeployPromptTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../..", __DIR__)
  @shared_prompt Path.join(@repo_root, "src/prompts/shared-agent-instructions.md")

  test "routes workspace-inaccessible hands-on checks to explicit post-deploy gates" do
    prompt = File.read!(@shared_prompt)

    assert prompt =~ "do not raise an operator decision and do not pause"
    assert prompt =~ "Post-deploy check: <exact steps>"
    assert prompt =~ "operator with the physical Stream Deck"
  end
end
