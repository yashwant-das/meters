# Roadmap

Planned work, without committed release dates. Items below are not implemented yet.

## Local LLM token tracking

### First: oMLX

- [ ] Verify endpoint availability and payloads against supported installed versions.
- [ ] Add an optional local oMLX connection with configurable server address and secure API-key storage.
- [ ] Show active model, generated tokens, generation speed, and idle/prefilling/generating state in the popover.
- [ ] Poll `/admin/api/activity` approximately every 1–2 seconds while the popover is visible; reduce polling when hidden or idle.
- [ ] Distinguish the server's average generation speed from any recent rate calculated from token-count changes.
- [ ] Handle concurrent requests, completed requests, missing metrics, connection failures, and authentication failures without displaying invented counts or speeds.
- [ ] Consider session token totals using `/admin/api/stats` after live tracking is validated.

Current upstream activity data includes per-request `generated_tokens`, `tokens_per_second`, and `prompt_tokens`. Admin endpoints generally require the main API key. Access should remain read-only; no inference proxy is needed for this integration.

References: [oMLX admin API](https://github.com/jundot/omlx/blob/main/docs/admin-api.md), [activity endpoint implementation](https://github.com/jundot/omlx/blob/main/omlx/admin/routes.py).

### Later: Ollama

- [ ] Detect the local server and loaded models through `/api/ps`.
- [ ] Evaluate an opt-in local proxy or instrumentation hook for observing requests made by other apps.
- [ ] Collect exact prompt/output token totals and completed-request generation speed from the final response statistics.
- [ ] Investigate token-aware instrumentation for genuine live counts; do not equate streaming chunks with tokens.
- [ ] Make any required client connection changes explicit before enabling the integration.

Ollama's documented response metrics arrive when generation finishes. Its running-model API does not expose live token counters. Passive live tracking across existing apps is therefore not currently a confirmed capability; validate the integration approach before promising parity with oMLX.

References: [Ollama usage metrics](https://docs.ollama.com/api/usage), [running-model API](https://docs.ollama.com/api/ps).

### Shared product decisions

- [ ] Decide whether tracking covers all server activity or selected models/requests.
- [ ] Decide which metrics belong in the popover and whether tokens/sec should also be an optional menu bar item.
- [ ] Preserve Meters' native macOS appearance and low resource usage.
- [ ] Keep collection limited to usage metadata; avoid storing prompts or responses.

## Other planned improvements

- [ ] Network and disk activity.
- [ ] Choose which metrics appear in the menu bar.
- [ ] Custom refresh interval.
