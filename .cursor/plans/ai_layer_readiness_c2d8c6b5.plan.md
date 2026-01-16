---
name: ai_layer_readiness
overview: Add lightweight API DTOs, strict parsing, timeout/rate-limit handling, and forward-compatible UI for AI-layer fields while keeping existing chat/apply UX intact.
todos:
  - id: api-models
    content: Add api DTOs + errors with strict parsing
    status: completed
  - id: chat-service
    content: Update ChatService to use DTOs + guardrails
    status: completed
  - id: chat-ui
    content: Update chat UI errors, apply checks, warnings, traceId UI
    status: completed
  - id: action-ui
    content: Add optional title/summary/confidence rendering
    status: completed
---

## Scope

- Add typed API models + parse/validation helpers in new files: [`lib/api/api_models.dart`](lib/api/api_models.dart) and [`lib/api/api_errors.dart`](lib/api/api_errors.dart).
- Refactor [`lib/chat/chat_service.dart`](lib/chat/chat_service.dart) to return typed responses, enforce timeouts, parse 429s, and log redacted metadata.
- Update [`lib/screens/chat_screen.dart`](lib/screens/chat_screen.dart) to enforce max length, handle new error types, render warnings/traceId UX, and only mark apply success when verified.
- Extend action rendering in [`lib/screens/chat_screen.dart`](lib/screens/chat_screen.dart) (and possibly [`lib/chat/chat_models.dart`](lib/chat/chat_models.dart)) to surface optional title/summary/confidence without changing existing helper text.

## Implementation plan

- **API models & errors**
- Create `ApiParseException`, `ApiHttpException`, `ApiRateLimitedException` in `lib/api/api_errors.dart`, storing `traceId` when present.
- Create DTOs in `lib/api/api_models.dart`:
- `ChatApiResponse` with required `assistantText`, `proposedActions`, optional `apiVersion`, `entities`, `warnings`, `traceId`.
- `ProposedActionDto` with `id`, `type`, `status`, `payload`, optional `title`, `summary`, `confidence`.
- `ApplyApiResponse` with required `appliedActionIds`, optional `failedActionIds`, `changes`, `message`, `traceId`, `apiVersion`.
- `ChangeDto` for apply changes.
- Parsing: fail closed; unknown fields ignored; throw `ApiParseException` (with traceId when available).

- **ChatService guardrails**
- Add constants `kChatTimeout`, `kApplyTimeout`, `kMaxMessageChars` (moved to service for shared use).
- Update `_postJson` to:
- Apply per-endpoint timeout.
- Parse JSON once and extract `traceId` for errors.
- On `429`, parse `Retry-After` header or `retryAfterSeconds` in body, throw `ApiRateLimitedException`.
- On other non-2xx, throw `ApiHttpException` with redacted body snippet and traceId.
- Log endpoint, status code, elapsed ms, response byte length, traceId (if any); log message length + redacted preview only.
- Change signatures to `Future<ChatApiResponse> postMessage(...)` and `Future<ApplyApiResponse> applyActions(...)`.

- **Chat screen UX + strict apply**
- Enforce message length using `kMaxMessageChars` and show toast: “Message is too long (max 500 chars).”.
- Catch and map errors to specific toasts: rate-limit, timeout, parse, default.
- Render warnings under assistant text when present.
- Apply flow: only set applied status and show “✅ Updated budgets.” when `ApplyApiResponse.appliedActionIds.contains(action.id)`; otherwise show failure toast.
- If apply `changes` exist, append a short assistant message summarizing changes (truncate to 1 line).
- Include `traceId` in debugPrints and add a debug-only “Copy trace id” action for errors (kDebugMode).

- **Action cards forward compatibility**
- Extend `ProposedAction` (or map from `ProposedActionDto`) to carry `title`, `summary`, `confidence`.
- In `_buildActionCard`, show `title` when provided; else existing generated title. Show `summary` as subtitle if present. Render subtle confidence badge.
- Do not change existing helper text.

## Notes

- Keep refresh after apply DB-only: continue using `PodsRefreshBus` and avoid any Sequence dependency.
- Maintain current behavior for successful paths; guardrails only alter failure handling and parsing.