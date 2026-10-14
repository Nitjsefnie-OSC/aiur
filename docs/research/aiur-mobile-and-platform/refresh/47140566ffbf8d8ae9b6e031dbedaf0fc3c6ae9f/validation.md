# Worker validation

Policy: research-only procedure draft; no runtime changes or new tests.

- python3 scripts/test_plan_refresh.py -> 17 named existing CLI fixtures pass.
- python3 scripts/check-bare-assert-receive.py -> OK (1596 test files).
- git apply --check against private pinned research export -> pass.
- All new report shards <=440 lines; concatenation exactly reproduces 9,949-line raw report.
- No preexisting oversized Markdown file grows.
- Same-range replay of three edited tickets -> 19 citations: 4 changed, 4 shifted, 7 OK, 4 unresolved. This proves replay is not an all-OK acceptance check.
- No mix lint/compile or TUI run claimed: research documentation only; no runtime edits or main PR. The research commit and push are authorized by the Executor.

## Three direct destination checks

### MP-E1-C1-T01

`src/lib/aiur/github/labels.ex:25` → `src/lib/aiur/github/labels.ex:26` at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f.

```elixir
  @state_suffixes ~w(todo in-progress ci-wait human-review rework merging done error cancelled canceled)
```

### MP-E1-C1-T03

`src/lib/aiur/linear/tracker.ex:139-142` → `src/lib/aiur/linear/tracker.ex:141-144` at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f.

```elixir
  def add_label(_issue_id, _label), do: {:error, :unsupported}

  @spec remove_label(String.t(), String.t()) :: {:error, term()}
  def remove_label(_issue_id, _label), do: {:error, :unsupported}
```

### MP-E1-C1-T04

`src/lib/aiur/tracker.ex:86-107` → `src/lib/aiur/tracker.ex:120-141` at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f.

```elixir
  def update_issue_state(issue_id, state_name, opts)
      when is_binary(issue_id) and is_binary(state_name) and is_list(opts) do
    tracker_adapter = adapter()

    cond do
      Code.ensure_loaded?(tracker_adapter) and
          function_exported?(tracker_adapter, :update_issue_state, 3) ->
        dispatch_update_issue_state(tracker_adapter, issue_id, state_name, opts)

      opts == [] ->
        tracker_adapter.update_issue_state(issue_id, state_name)

      true ->
        {:error, :expected_state_unsupported}
    end
  end

  @spec dispatch_update_issue_state(module(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  defp dispatch_update_issue_state(tracker_adapter, issue_id, state_name, opts) do
    tracker_adapter.update_issue_state(issue_id, state_name, opts)
  end
```

## Executor corrections validation

- All 243 corrected research files match the intended draft byte-for-byte.
- All nine E6 size_owner fields equal their original ticket rationales; prospective ticket-start decisions remain in admissions.md.
- Every refreshed citation stamp names the validated destinations; ticket base_sha values are unchanged.
- Actual pinned-main units_row_test.exs count: 490 LF-counted lines; reference counts labelled pre-move at 45a290e3.
- Open-review lists contain exactly 2486 old-baseline entries and 4039 full-pack unresolved entries, assigned by feature; populations overlap.
- `mise exec -- python3 scripts/check-pr-structure.py --base 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f` -> exit 2: scripts/check-pr-structure.py does not exist on research/refactor-findings. The research branch predates the main-only gate; no structural pass is claimed and no runtime/main tooling is imported to this research-only commit. Local patch, size, metadata, citation and whitespace checks pass.
