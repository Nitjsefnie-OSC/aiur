# Integration configuration

## elevenlabs

Both capture clients stream audio to Aiur, and Aiur calls ElevenLabs with the credential below; interactive conversation also streams speech audio back to the browser. This is the only place the credential is configured, and neither the sidecar nor the browser holds it.

This optional section configures voice features; `aiur init` records declines as `enabled: false` and skips them on resume.

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `elevenlabs.enabled` | boolean | true | Enables ElevenLabs voice features. Set false to keep an explicit declined setup choice and suppress configured or environment-provided credentials. Existing configs without this key remain enabled. |
| `elevenlabs.api_key` | string or nil | nil | ElevenLabs credential. Accepts a literal value or a `$ELEVENLABS_API_KEY` environment reference. Speech input needs Speech to Text permission; spoken replies also need Text to Speech permission. |
| `elevenlabs.language_code` | string | `eng` | ISO-639-3 transcription language. ElevenLabs uses `eng` for English. |
| `elevenlabs.voice_id` | string or nil | nil | Stock or owned ElevenLabs voice used for Dashboard interactive conversation replies. Find the identifier in **My Voices**; Aiur does not clone or manage voices. |

`ELEVENLABS_API_KEY` is the environment variable for the credential. When `elevenlabs.enabled` is true, an explicit `elevenlabs.api_key` value wins; when the key is absent, or is the `$ELEVENLABS_API_KEY` reference, the variable supplies it. `enabled: false` suppresses both sources. An environment variable set to the empty string resolves to no key.

The key is a secret. Keep it in `.env` and leave the `$ELEVENLABS_API_KEY` reference in the config file rather than pasting the value there. Aiur never logs the key, and the daemon scrubs every `*_API_KEY` variable, `ELEVENLABS_API_KEY` included, from agent process environments, local and SSH-launched alike, so no coding agent inherits it.

Configuring the key also adds an ElevenLabs meter to the Dashboard Units page, beside the GitHub API meter. It reads the account credit quota and next-invoice amount due from `GET /v1/user/subscription`; with no key configured the meter is absent entirely. See [API meters](/concepts/units#api-meters) for what each figure does and does not measure.

## opencode

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `opencode.command` | string | `opencode` | Command launching opencode. |
| `opencode.bridge_port` | integer | 4097 | Aiur↔opencode bridge port. |
| `opencode.bridge_host` | string | `127.0.0.1` | Aiur↔opencode bridge host. |
| `opencode.serve_args` | array | `[]` | Extra `opencode serve` arguments. |
| `opencode.model_prefix` | string | `aiur` | Prefix for registered synthetic models. |
| `opencode.prewarm_disabled` | boolean | false | Disables opencode session pre-warming. |

## experiments
The daemon owns [experiment](../concepts/experiments) writes through control RPC.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `experiments.enabled` | boolean | true | Start the experiment store. Disabled stores refuse writes. |
| `experiments.default_min_samples` | integer | 15 | Minimum samples per arm; positive. |
| `experiments.default_before_days` | integer | 14 | Default baseline window in days; positive. |
| `experiments.pack_dirs` | string list | [".aiur/experiments/packs"] | Consumer metric pack directories, relative to the base checkout; reserved for metric packs. |
| `experiments.disabled_packs` | string list | [] | Pack IDs to disable; reserved for metric packs. |
| `experiments.script_timeout_ms` | integer | 60000 | Script metric timeout in milliseconds; positive, reserved for metric packs. |
| `experiments.checkpoint_interval_ms` | integer | 3600000 | Observation checkpoint interval in milliseconds; positive, reserved for snapshot capture. |
| `experiments.max_snapshot_observations` | integer | 50000 | Maximum observations in a snapshot; positive, reserved for snapshot capture. |
