---
name: Pixel nav icons (no settings)
overview: Replace the 4 bottom navigation Material icons with custom pixel-style SVG assets matching the app’s 8-bit branding, and update tab labels/icons to be finance/budgeting-oriented. Settings remains elsewhere via its own route.
todos:
  - id: add-svg-assets
    content: Create 4 pixel-style monochrome SVG nav icons under `assets/icons/nav/` (overview, budgets, guide, transactions).
    status: completed
  - id: wire-assets
    content: Add the new icons directory to `pubspec.yaml` assets list and ensure Flutter picks them up.
    status: completed
  - id: pixel-icon-widget
    content: Add a small `PixelNavIcon` widget that renders an SVG using the current `IconTheme` color (selected/unselected support).
    status: completed
    dependencies:
      - add-svg-assets
  - id: update-bottom-nav
    content: Update `AppShell` bottom nav items to use `PixelNavIcon` + new finance-oriented labels (keeping the same 4 route branches).
    status: completed
    dependencies:
      - wire-assets
      - pixel-icon-widget
---

# Pixel-style finance nav icons (Settings excluded)

## What will change

- Update the bottom navigation in [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/shell/app_shell.dart) to use **custom pixel SVG icons** (instead of `Icons.*`) and to use **finance/budgeting-oriented labels**.
- Add a small reusable widget (e.g. `PixelNavIcon`) that renders an SVG using the current `IconTheme` color, so selected/unselected colors work naturally.
- Add new SVG assets under `assets/icons/nav/` and include them in [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/pubspec.yaml`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/pubspec.yaml).

## Important clarification about Settings

- **Settings is not part of the bottom nav anymore**.
- The `/settings` route still exists (e.g. reachable via `lib/widgets/user_menu_sheet.dart`), but it is **out of scope** for this change.

## Current code location (source of truth)

The current bottom nav items are here:

```20:36:lib/shell/app_shell.dart
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'Pods',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Guide'),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Activity',
          ),
        ],
      ),
```



## Proposed new 4 tabs (labels + icon meanings)

Defaults (we can tweak wording to match your terminology):

- **Overview** (was Home): pixel “dashboard/summary” icon
- **Budgets** (was Pods): pixel “jar/envelope” icon
- **Guide**: pixel “lightbulb/chat” icon
- **Transactions** (was Activity): pixel “receipt/list” icon

Routes/branches stay the same (only the bottom-nav presentation changes).

## Icon implementation details

- Create 4 small **monochrome** SVGs built from rectangles on a consistent grid (e.g. 24×24 viewBox, 2px “pixels”) to match the logo’s pixel aesthetic.
- Use `flutter_svg` to render them.
- Ensure correct theming:
- Use `BottomNavigationBarItem(icon: ..., activeIcon: ...)` or a `PixelNavIcon` widget that reads `IconTheme.of(context).color` and applies it via `colorFilter`.
- This preserves standard selected/unselected behavior and dark mode contrast.

## Files to touch

- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/shell/app_shell.dart)
- Add: `lib/widgets/pixel_nav_icon.dart` (or similar)
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/pubspec.yaml`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/pubspec.yaml)
- Add: `assets/icons/nav/*.svg`

## Quick acceptance check (what you’ll see)

- Bottom nav shows crisp pixel icons matching the 8-bit vibe of `assets/branding/logo-main.png`.