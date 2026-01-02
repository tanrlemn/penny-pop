---
name: Envelopes budget screen
overview: "Rename Pods to Envelopes and turn the Pods list into an envelope-budgeting view: top income/expense summary, sectioned list (Income + expense sections), fast budget editing, and “Needs / +$” indicators based on synced balances vs budgeted targets."
todos:
  - id: db-budgeted-income
    content: "Add migration: add `pod_settings.budgeted_amount_in_cents` and extend category check to include `Income`."
    status: completed
  - id: edge-sync-income-sources
    content: Update Edge Function `sync-pods` to import Sequence `Income Source` accounts and create default `pod_settings(category=Income)` when missing.
    status: completed
    dependencies:
      - db-budgeted-income
  - id: flutter-models-service
    content: Extend `PodSettings` + `PodsService` to read/write `budgeted_amount_in_cents` via `pod_settings` join/upsert.
    status: completed
    dependencies:
      - db-budgeted-income
  - id: ui-envelopes-summary-sections
    content: "Update `PodsScreen` UI: rename to Envelopes, add top summary, render Income + expense sections with section totals and per-row Needs/+ indicators."
    status: completed
    dependencies:
      - flutter-models-service
      - edge-sync-income-sources
  - id: ui-fast-edit-budgeted
    content: Implement row tap → fast budgeted edit sheet (budgeted + optional section picker), save via `upsertPodSettings`; keep balance read-only.
    status: completed
    dependencies:
      - flutter-models-service
  - id: rename-tab-label
    content: Rename bottom tab label from Pods → Envelopes and update nav title accordingly.
    status: completed
---

# Envelopes (Budget) screen refresh

## Goals

- Rename the tab + page from **Pods** → **Envelopes**.
- Add a **top summary** above the list:
- Total Income (sum of Income envelopes’ budgeted)
- Total Budgeted Expenses (sum of non-Income budgeted)
- Left to Budget = Income − Expenses
- If negative, show **“Over budget by $X”**; if positive, show **“Unassigned $X”**
- Optional: Left to Budget % = Left / Income
- Replace the flat list with **sectioned rendering**:
- **Income** section: rows show Name + Budgeted + “% of Total Income” subtext
- **Expense sections** (Necessities, Pressing, Savings, Kiddos, Discretionary, plus optional Uncategorized):
    - section header shows section total + **% of Total Income**
    - each row shows Name + Budgeted + Balance + small indicator:
    - if Balance < Budgeted: “Needs $X”
    - if Balance > Budgeted: “+$X”
- Tap a row → **edit Budgeted** (fast). Balance stays read-only.

## Key discovery / constraint

The current Sequence sync only imports accounts whose `type` looks like “Pod”. You chose to **also sync Sequence “Income Source”** accounts so the Income section can be real and not manual.

## Data model changes (minimal)

### Supabase

- Add a new migration in `supabase/migrations/` to extend `pod_settings`:
- Add `budgeted_amount_in_cents bigint` (nullable)
- Extend existing `pod_settings.category` CHECK to include `'Income'` (we’ll treat this column as the UI “section” for now)

### Sync behavior

- Update the Edge Function [`supabase/functions/sync-pods/index.ts`](supabase/functions/sync-pods/index.ts):
- Import both account types:
    - “Pod” → regular envelopes
    - “Income Source” → income envelopes
- For any imported “Income Source” rows, create a `pod_settings` row **if missing** with `category='Income'` (do not overwrite user edits).

## App changes

### 1) Rename tab + title

- Update bottom tab label in [`lib/shell/app_shell.dart`](lib/shell/app_shell.dart) from `Pods` → `Envelopes`.
- Update navigation bar title in [`lib/screens/pods_screen.dart`](lib/screens/pods_screen.dart) from `Pods` → `Envelopes`.
- Keep route `/pods` unchanged for now (minimize routing churn).

### 2) Extend Pods domain model

- Update [`lib/pods/pod_models.dart`](lib/pods/pod_models.dart):
- Add `budgetedAmountCents` to `PodSettings`.
- Parse it from the `pod_settings` join.
- Update [`lib/pods/pods_service.dart`](lib/pods/pods_service.dart):
- Include `budgeted_amount_in_cents` in `listPods()` select.
- Extend `upsertPodSettings()` to write `budgeted_amount_in_cents`.

### 3) Implement Envelopes UI (same screen, new layout)

In [`lib/screens/pods_screen.dart`](lib/screens/pods_screen.dart):

- Compute totals from `_pods`:
- Income pods: `settings.category == 'Income'`
- Expenses: everything else
- Add a top summary using `GlassCard` (`lib/design/glass/glass_variants.dart`) so it matches the existing glass system.
- Render a sectioned list:
- Income section
- Expense sections in the existing order
- Optional: “Uncategorized” section for pods with null/empty category
- For each expense row:
- `needsCents = max(0, budgeted - balance)`
- `surplusCents = max(0, balance - budgeted)`
- Show `Needs $X` or `+$X` (only when both budgeted + balance exist).

### 4) Fast edit flow for Budgeted

- Replace current tap action (category/notes sheet) with a fast “Budgeted” edit sheet:
- Numeric input for dollars (we’ll parse to cents)
- Optional quick section picker (since section assignment is important for Income vs Expense)
- Save → `PodsService.upsertPodSettings(podId, category, budgetedAmountCents)`

## Validation / testing

- After implementing, verify:
- Income sources appear after Sync and default into Income.
- Summary math matches expectations for positive/negative Left to Budget.
- Needs / +$ indicator matches `balance - budgeted`.
- Editing budgeted updates totals immediately after save.

## Files to change

- [`lib/screens/pods_screen.dart`](lib/screens/pods_screen.dart)
- [`lib/shell/app_shell.dart`](lib/shell/app_shell.dart)
- [`lib/pods/pod_models.dart`](lib/pods/pod_models.dart)