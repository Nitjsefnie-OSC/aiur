# RC-19/RC-20 source check

All four watched paths changed in 45a290e3..47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f. Verified at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f:

- C1-T01: github/labels.ex:35-37 includes queued in marker suffixes; github/issues.ex:1155 calls Labels.marker_suffix?/1 while parsing state labels.
- C1-T02: orchestrator/issue_sync.ex:239 and :443 preserve Issue.queued? in strand and heal exemptions.
- C1-T03: github/issues.ex:366, :402 call record_open_issues; :408 delegates to OpenIssueListing.record. Inspect the listing adapter before claiming complete snapshot behavior.
- C1-T05: orchestrator/dispatch_policy.ex:130 uses Hints.sort_key; :387 uses Hints.held? to decline dispatch.
- Single state-writer seam: build_queue/server.ex:427 invokes Writer.run; writer.ex invokes WriteProtocol.attempt; write_protocol.ex:43 promotes via TicketTransition.write_state with writer: :build_queue and expected_state: :none; :47 changes markers through TicketTransition.write_marker. orchestrator/ticket_transition.ex:20 invokes tracker.update_issue_state inside with_writer. No direct queue update_issue_state call found outside that sanctioned seam.

This is source evidence, not runtime testing. No missing hook was detected in the inspected call paths. No hook code is changed by this draft.
