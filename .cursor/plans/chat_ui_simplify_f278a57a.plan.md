---
name: chat_ui_simplify
overview: Simplify chat UI to show plain assistant text, compact action cards with preview, and chips only when clarification is required, based on backend response shape you provided.
todos:
  - id: map-ui-state
    content: Add view-model mapping for assistant/actions/clarify
    status: completed
  - id: chips-gating
    content: Show chips only when clarification needed
    status: completed
  - id: action-card
    content: Compact action card with title/subtitle/preview
    status: completed
  - id: assistant-text
    content: Ensure assistant bubble is plain English
    status: completed
---

# Chat UI Simplification Plan

## Context

- Primary changes live in `lib/screens/chat_screen.dart` where chat bubbles, chips, and action cards are rendered.
- Backend responses include `assistantText`, `proposedActions`, and `entities` with `candidates`, plus optional `fromCandidate`/`toCandidate`.

## Plan

- **Add a lightweight UI view model mapping** in `ChatScreen` to convert raw response → `assistantText`, `actions`, and `clarification` (needed source/target + choices). This will prevent raw JSON and candidates from leaking into the UI.
- **Gate candidate chips** so they only render when the response has *no* proposed actions and the intent is partial/ambiguous. Use `entities.fromCandidate`/`toCandidate` and non-empty `candidates` to decide which clarification prompt to show.
- **Rename action card titles** based on `type` in `proposedActions` (e.g., `budget_transfer` → `Move $X`) and include preview lines from payload (`from_pod_name`, `to_pod_name`, `amount_in_cents`).
- **Refactor action card UI** into the compact format: title, subtitle (From → To), optional preview lines, and buttons (Apply, Edit [stub], Cancel/Ignore). Keep “Edit” disabled for now if no handler exists.
- **Ensure assistant bubble text is human-readable**: when `assistantText` is empty, derive a simple sentence from the action payload instead of `data.toString()`.

## Files to Change

- `lib/screens/chat_screen.dart`
- Add a small view-model struct/class for `ChatItem` to store `clarification` and structured action info.
- Update `_resolveAssistantMessage`, `_resolveActions`, and `_resolveCandidates` to produce the new UI state.
- Update `_buildMessageRow` to render only text, optional clarification chips, and compact action cards.

## Notes on Clarification Logic

- Show chips only when:
- `proposedActions` is empty, and
- there is `entities.candidates`, and
- `fromCandidate` or `toCandidate` is missing.
- Clarification label example: “Pick the source” if `fromCandidate` missing; “Pick the destination” if `toCandidate` missing.

## Testing

- Manually exercise with the two sample responses:
- Empty `proposedActions` + candidates → assistant text only + clarification chips.
- `budget_transfer` action → assistant text + compact action card; no chips.