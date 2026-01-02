---
name: Budget sheet UX polish
overview: Improve the envelope budget edit sheet so the amount is immediately editable, Save stays reachable above the keyboard, and the user gets live “Available/Needs/Over” feedback while typing.
todos:
  - id: budgetsheet-autofocus
    content: Auto-focus the amount field on open (FocusNode + select-all) in `_PodBudgetSheetState`.
    status: completed
  - id: budgetsheet-sticky-footer
    content: Refactor `_PodBudgetSheet` layout so Save/Done is in a sticky footer that stays above the keyboard using `viewInsets.bottom`.
    status: completed
  - id: budgetsheet-live-preview
    content: Add a live preview block that recomputes Available/Needs/Over/On-target (and overspent warning) as `_budgeted` changes.
    status: completed
    dependencies:
      - budgetsheet-sticky-footer
  - id: budgetsheet-category-6
    content: "Update the Category row to show only 6 options (no Uncategorized/search) and display `Category: X >` under the header."
    status: completed
---

# Envelope budget sheet UX improvements

## Goals
- **Default focus on amount** when the sheet opens (keyboard opens, text selected).
- **Keyboard-safe sticky footer** so **Save/Done is always reachable**.
- **Instant feedback** while typing: show **Available** (current balance), plus **Needs/Over/On target** vs the entered budget, with inline warning styling.
- **Category change stays secondary**: a single row under the header (`Category: X >`) with **only 6 options** (no search, no Uncategorized option).

## Primary files to change
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/pods_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/pods_screen.dart)
  - Update `_PodBudgetSheet` / `_PodBudgetSheetState`.

## Implementation approach
- **Auto-focus + select-all**
  - Add a `FocusNode` for the budget field.
  - In `initState`, `addPostFrameCallback` to `requestFocus()` and set `TextSelection` to select all existing text.

- **Sticky footer above keyboard**
  - Restructure the sheet body from “ListView contains Save button” to:
    - Header (handle + title + close)
    - `Expanded(ListView(...))` for content
    - Bottom **footer bar** containing the Save button.
  - Use `MediaQuery.viewInsetsOf(context).bottom` (with `AnimatedPadding`) so the footer lifts above the keyboard.

- **Instant feedback block (live preview)**
  - Add an `AnimatedBuilder` (or `ValueListenableBuilder`) that listens to `_budgeted` (`TextEditingController` is a `Listenable`).
  - Recompute as the user types:
    - `budgetedCents = _parseMoneyToCents(_budgeted.text)`
    - `availableCents = widget.pod.balanceCents` (unless `balanceError != null`)
    - `diff = availableCents - budgetedCents`
  - Display:
    - **Available**: current balance
    - **Result**: `Needs $X` (red) if diff < 0, `+$X` (green) if diff > 0, `On target` otherwise
    - If `availableCents < 0`, show **Overspent** warning (red)
    - If `balanceError != null`, show a muted “preview unavailable” message

- **Category row (6 options only)**
  - Keep the row UI but label it `Category` and display `Category: <value> >`.
  - Update `_pickSection()` action sheet to show **only** `widget.sectionOptions` (currently 6: Income + 5 expense sections) and remove the `Uncategorized` action.
  - If the current stored category is null/unknown, display `Uncategorized` as a label, but don’t offer it as a selectable action.

## Acceptance checks
- Opening “Envelope budget” brings up the keyboard and places the caret in the amount field with text selected.
- With the keyboard open, the **Save** button remains visible and tappable (no scrolling required).
- Typing updates the preview immediately (including red/green state).
- Category chooser shows exactly 6 options; no search UI.

## Implementation todos
- `budgetsheet-autofocus`: Add `FocusNode` + `initState` post-frame focus/selection + dispose.
- `budgetsheet-sticky-footer`: Refactor layout to a sticky footer that pads above `viewInsets.bottom`.
- `budgetsheet-live-preview`: Add live computation + UI block for Available/Needs/Over + warnings.
- `budgetsheet-category-6`: Change category row label and restrict action sheet options to 6.