defmodule Aiur.Workspace.BootstrapImageTest do
  use Aiur.TestSupport

  alias Aiur.Workspace.BootstrapImage

  setup do
    test_root = Aiur.TestSupport.tmp_root!("bi_test")
    workspace = Path.join(test_root, "ws")
    File.mkdir_p!(workspace)

    on_exit(fn -> Aiur.TestCleanup.rm_rf!(test_root) end)
    {:ok, workspace: workspace, test_root: test_root}
  end

  test "maybe_seed/3 with no bootstrap_image configured returns :ok", %{workspace: workspace} do
    issue_context = %{
      issue_id: 1,
      issue_identifier: "test",
      issue_state: nil,
      issue_labels: [],
      pr_head_ref: nil
    }

    assert :ok = BootstrapImage.maybe_seed(workspace, issue_context, nil)
  end

  test "bootstrap_image_copy_script/0 contains exit 66 and all four cache paths" do
    script = BootstrapImage.bootstrap_image_copy_script()

    assert script =~ "exit 66"
    assert script =~ "src/deps"
    assert script =~ "src/_build"
    assert script =~ "deps"
    assert script =~ "_build"
  end

  test "bootstrap_image_copy_script/0 starts with set -eu and contains a for-loop over cache paths" do
    script = BootstrapImage.bootstrap_image_copy_script()

    assert String.starts_with?(script, "set -eu\n")
    assert script =~ "for path in"
    assert script =~ "found=0"
  end

  test "bootstrap_image_copy_script/0 drops first-party test beams after seeding" do
    script = BootstrapImage.bootstrap_image_copy_script()

    assert script =~
             ~s(rm -rf "$workspace_root/src/_build/test/lib/aiur" "$workspace_root/_build/test/lib/aiur")
  end

  @tag timeout: 300_000
  test "a seeded build from another checkout recompiles path-sensitive static assets", %{test_root: root} do
    repo_root = File.cwd!() |> Path.dirname()
    ticket_checkout = Path.join(root, "ticket-checkout")
    ticket_src = Path.join(ticket_checkout, "src")
    archive = Path.join(root, "seed.tar")

    assert {_, 0} = System.cmd("git", ["-C", repo_root, "archive", "--format=tar", "HEAD", "-o", archive])
    File.mkdir_p!(ticket_checkout)
    assert {_, 0} = System.cmd("tar", ["-xf", archive, "-C", ticket_checkout])
    File.cp!(Path.join(repo_root, "src/lib/aiur/workspace/bootstrap_image.ex"), Path.join(ticket_src, "lib/aiur/workspace/bootstrap_image.ex"))

    assert {_, 0} =
             System.cmd("ln", ["-s", Path.join(repo_root, "src/deps"), Path.join(ticket_src, "deps")])

    File.mkdir_p!(Path.join(ticket_src, "_build"))

    assert {_, 0} =
             System.cmd("cp", ["-R", Path.join(repo_root, "src/_build/test"), Path.join(ticket_src, "_build/test")])

    assert File.dir?(Path.join(ticket_src, "_build/test/lib/aiur"))

    assert {_, 0} =
             System.cmd("sh", ["-c", BootstrapImage.bootstrap_image_copy_script(repo_root, ticket_checkout)],
               cd: repo_root,
               stderr_to_stdout: true
             )

    refute File.exists?(Path.join(ticket_src, "_build/test/lib/aiur"))

    assert {output, 0} =
             System.cmd("mix", ["test", "--max-cases", "4", "test/aiur_web/static_assets_css_test.exs"],
               cd: ticket_src,
               env: [{"MIX_ENV", "test"}],
               stderr_to_stdout: true
             )

    assert output =~ "4 tests, 0 failures"
  end

  test "bootstrap_image_script/3 includes docker pull when pull? true, omits it when false" do
    workspace = "/tmp/test-workspace"
    image = "test-image:latest"

    with_pull = BootstrapImage.bootstrap_image_script(workspace, image, true)
    without_pull = BootstrapImage.bootstrap_image_script(workspace, image, false)

    assert with_pull =~ "docker pull"
    refute without_pull =~ "docker pull"

    assert with_pull =~ "docker run --rm --user"
    assert without_pull =~ "docker run --rm --user"
  end
end
