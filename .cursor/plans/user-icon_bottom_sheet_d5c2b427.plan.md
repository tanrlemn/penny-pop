---
name: User-icon bottom sheet
overview: Move Settings access from the bottom nav into a top-right user icon that opens a modal bottom sheet menu, with routing to existing settings pages.
todos:
  - id: remove-settings-tab
    content: Remove Settings bottom navigation item and adjust shell to 4 tabs
    status: completed
  - id: move-settings-routes
    content: Move /settings routes out of StatefulShellRoute into top-level GoRoutes with nested subroutes
    status: completed
    dependencies:
      - remove-settings-tab
  - id: user-menu-sheet
    content: Add reusable showModalBottomSheet user menu with navigation + sign out
    status: completed
    dependencies:
      - move-settings-routes
  - id: add-appbar-icon
    content: Add top-right user icon action to Home/Pods/Coach/Activity app bars
    status: completed
    dependencies:
      - user-menu-sheet
---

# Move Settings behind user icon

## Goal

- Remove the **Settings** bottom-tab.
- Add a **user icon** in the **top-right AppBar** on every main tab (Home/Pods/Coach/Activity).
- Tapping the icon opens a **bottom-sheet drawer** (modal) with a compact menu that can navigate to Settings-related screens.

## Approach

### 1) Replace the Settings bottom tab with a top-right user icon

- Update [`lib/shell/app_shell.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/shell/app_shell.dart):
- Remove the Settings `BottomNavigationBarItem` so there are only 4 tabs.

### 2) Move Settings routes out of the tab shell

- Update [`lib/routing/app_router.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/routing/app_router.dart):
- Remove the `StatefulShellBranch` that currently hosts `/settings`.
- Add a **top-level** `GoRoute(path: '/settings', builder: ...)` that points to `SettingsScreen`.
- Keep nested subroutes under it:
    - `/settings/me` → `MeScreen`
    - `/settings/add-partner` → `AddPartnerScreen`
- Result: Settings becomes a normal pushed route (no longer a tab), reachable from the bottom sheet.

### 3) Implement the bottom “drawer” as a reusable modal bottom sheet

- Add a new helper in [`lib/widgets/user_menu_sheet.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart):
- `Future<void> showUserMenuSheet(BuildContext context)`
- Uses `showModalBottomSheet` + `SafeArea` and a `ListView`.
- Menu contents (as ListTiles):
    - **Account & household** → `context.push('/settings')`
    - **My info** → `context.push('/settings/me')`
    - **Invite partner** (only if `active.role == 'admin'`) → `context.push('/settings/add-partner')`
    - **Sign out** → confirm dialog, then `AuthService.instance.signOut(alsoSignOutGoogle: true)`
- Header shows current email + household name (non-technical).

### 4) Add the user icon to each main tab AppBar

- Update these screens to include an `actions: [IconButton(...)] `calling `showUserMenuSheet(context)`:
- [`lib/screens/home_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/home_screen.dart)
- [`lib/screens/pods_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/pods_screen.dart)
- [`lib/screens/coach_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/coach_screen.dart)
- [`lib/screens/activity_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/activity_screen.dart)

## Notes / UX details

- The bottom sheet will close itself before navigating (pop sheet, then push route) to avoid stacked overlays.
- Because Settings becomes a pushed route, the bottom nav will not show while you’re on Settings pages (typically desirable for “account/settings” flows).

## Validation