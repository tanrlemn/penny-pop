---
name: Remove tab + delete settings screens
overview: Remove the 4th (Transactions/Activity) tab and delete the unused settings-related screens so there are no dead routes or accidental navigation landmines.
todos:
  - id: remove-activity-route
    content: Remove /activity branch from go_router and drop ActivityScreen import.
    status: completed
  - id: update-tabbar-3tabs
    content: Update AppShell glass tab bar to 3 tabs and fix bubble math/tabCount.
    status: completed
    dependencies:
      - remove-activity-route
  - id: delete-screens
    content: Delete Activity/Settings/Me/AddPartner screen files and confirm no remaining references.
    status: completed
    dependencies:
      - remove-activity-route
---

# Remove Transactions tab + settings screens

## Goal

- Remove the **Transactions** tab (currently the `/activity` branch) entirely.
- Remove the “settings route” landmine by **deleting** the unused settings-related screens.

## Changes

### Navigation (remove 4th tab)

- Update [`lib/routing/app_router.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/routing/app_router.dart)
- Remove the `ActivityScreen` import.
- Remove the `StatefulShellBranch` that defines `path: '/activity'`.
- Result: the shell has **3 branches**: `/` (Overview), `/pods`, `/guide`.
- Update [`lib/shell/app_shell.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/shell/app_shell.dart)
- Change the tab bar from **4 tabs → 3 tabs**:
    - Update `tabCount` from 4 to 3.
    - Remove the tab config for `label: 'Transactions'` / `assetPath: 'assets/icons/nav/transactions.svg'`.
    - Ensure the “bubble” positioning math still uses the correct `tabCount`.
- Delete [`lib/screens/activity_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/activity_screen.dart)
- It’s only referenced by the router and becomes unused after the route removal.

### Remove unused settings-related screens

- Delete the following files (they are currently **unrouted/unreachable** and create confusion):
- [`lib/screens/settings_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/settings_screen.dart)
- [`lib/screens/me_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/me_screen.dart)
- [`lib/screens/add_partner_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/add_partner_screen.dart)

## Verification / exit criteria

- App boots and routes correctly:
- `/splash` → `/login` when signed out; `/splash` → `/` when signed in.
- Tab bar shows exactly **3 tabs**: Overview, Pods, Guide.