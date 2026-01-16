---
name: overview-envelopes-simplify
overview: Implement Overview v1 (budget health + attention queue with simple computed rules), simplify Envelopes into a calm, collapsed ledger, and wire Overview actions into Chat/Envelopes navigation with context.
todos:
  - id: overview-v1
    content: Add BudgetSnapshotService + Overview UI
    status: completed
  - id: deep-links
    content: Add OverviewAction/PodsFocusTarget deep links
    status: completed
  - id: envelopes-simplify
    content: Collapse sections + search + soften balances
    status: completed
---

# Overview + Envelopes simplification

## Scope

- Implement Overview v1 on the existing Overview tab (`HomeScreen`) using a shared snapshot service (no dependency on `PodsScreen` state).
- Simplify Envelopes (`PodsScreen`) by collapsing sections, adding search, and de-emphasizing balances while keeping behavior stable.
- Wire Overview actions into Chat and Envelopes with typed `state.extra` payloads only.

## Implementation plan

- **Overview data + UI**
- Add a shared snapshot layer:
- [`lib/overview/budget_snapshot.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/overview/budget_snapshot.dart) (model)
- [`lib/overview/budget_snapshot_service.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/overview/budget_snapshot_service.dart) (loads pods + settings + income sources, computes totals)
- Replace the placeholder in [`lib/screens/home_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/home_screen.dart) with Overview v1:
- Budget Health card (status + primary number).
- Attention Queue (3–5 items max).
- Quick actions row: “Sync balances”, “Open Chat”, “Edit budgets”.
- Attention rules (v1-safe, non-authoritative):
- `leftToBudgetCents > 0` → “$X unassigned income”.
- `leftToBudgetCents < 0` → “$X over budget”.
- `missingBudgetCount > 0` → “Set budgets for N envelopes”.
- `uncategorizedCount > 0` → “Categorize N envelopes”.
- Optional: “Balances are stale — pull to refresh” if `balance_updated_at` is available.
- Define `AttentionItem` with: `id`, `title`, `subtitle`, `primaryAction`, optional `secondaryAction`.
- Optional dev-only UI toggles in `HomeScreen` to simulate attention states.

- **Deep links from Overview**
- Define `OverviewAction` and `PodsFocusTarget` (typed payload or a map with `type`).
- Update [`lib/routing/app_router.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/routing/app_router.dart) to pass `state.extra` into `ChatScreen` and `PodsScreen` constructors.
- Update [`lib/screens/chat_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/chat_screen.dart) to accept an optional initial prompt and prefill the message input (no autosend).
- Update [`lib/screens/pods_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/pods_screen.dart) to accept a `PodsFocusTarget` and scroll after `_load()` completes.

- **Simplify Envelopes**
- Keep the summary card but shrink it (lower visual weight).
- Default-collapse sections and allow toggle from section headers.
- Add a search bar at top of `PodsScreen`.
- Make balances secondary (smaller/muted); keep budgets primary.
- If sticky headers conflict with collapse/search, remove sticky header for v1 and revisit later.

## Validation

- Manual run:
- Overview shows Budget Health + Attention Queue and updates with real data.
- Attention items navigate correctly to Chat (prefilled prompt) or Envelopes (focus scroll after load).
- Envelopes defaults to collapsed sections, expands/collapses cleanly, search filters list, and balances read as secondary.

## Notes

- Attention items should be explicitly non-authoritative for v1.
- Recent Changes can be added later; current structure won’t block it.