---
name: Cupertino glass rollout
overview: Convert the app to a Cupertino-first iOS UI and introduce a small reusable glass design system (blur + tint + hairline border + depth), applying it first to the 4-tab shell and key overlays/surfaces.
todos:
  - id: add-glass-design-system
    content: Create `lib/design/glass/` tokens + `GlassSurface` (blur+tint+hairline border) with reduce-transparency fallback and a couple variants (bar/card/sheet).
    status: pending
  - id: switch-to-cupertino-app
    content: Update `PennyPopApp` to use `CupertinoApp.router` and set `CupertinoThemeData` (light/dark) aligned to glass tokens.
    status: pending
    dependencies:
      - add-glass-design-system
  - id: cupertino-pages-router
    content: Update `createAppRouter` routes to use `pageBuilder` with Cupertino page transitions for all primary routes and shell branches.
    status: pending
    dependencies:
      - switch-to-cupertino-app
  - id: glass-shell-tabbar
    content: Refactor `AppShell` to a Cupertino-friendly layout and implement a glass bottom tab bar driving `StatefulNavigationShell`; tune `PixelNavIcon` coloring for selected/unselected states.
    status: pending
    dependencies:
      - add-glass-design-system
      - cupertino-pages-router
  - id: convert-screens-overlays
    content: Convert key screens/overlays from Material to Cupertino-first (login/splash + tab screens as needed + `user_menu_sheet.dart`), replacing Material sheets/snackbars with Cupertino/glass equivalents.
    status: pending
    dependencies:
      - glass-shell-tabbar
---

# Cupertino-first “Liquid Glass” rollout (iOS-only)

## Goals
- Make the app feel like Apple’s material-driven “glass”: **real blur + subtle tint + hairline border + layered depth**, with good legibility.
- Move to a **Cupertino-first** widget stack so navigation, typography, and platform behaviors match iOS expectations.
- Keep the existing **4-tab shell** (Overview/Pods/Guide/Transactions) and restyle/convert it.

## Key files we’ll touch
- App root/theming: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart)
- Routing/transitions: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)
- Shell/tab bar: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart)
- Icons in nav: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart)
- Overlays: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart)
- Screens (convert as needed): `lib/screens/*.dart`

## Implementation outline
- Add a small glass design module under `lib/design/glass/`:
  - Tokens: blur sigma, opacities, corner radii, border widths, shadow/elevation equivalents.
  - `GlassSurface`: `ClipRRect` + `BackdropFilter` + tint + 1px border, with **reduce transparency** fallback (`MediaQuery.accessibilityFeatures.reduceTransparency`).
  - Variants/helpers for bar/card/sheet so we don’t hand-tune each screen.
- Switch app root to `CupertinoApp.router`:
  - Provide a global `CupertinoThemeData` aligned to glass tokens (light/dark), keep `ThemeMode.system`.
  - Ensure existing `GoRouter` integration stays intact.
- Update `go_router` routes to use **Cupertino pages/transitions**:
  - Convert route definitions from `builder:` to `pageBuilder:` using `CupertinoPage` (or equivalent) so transitions are iOS-native.
- Refactor `AppShell`:
  - Replace `Scaffold` + `BottomNavigationBar` with a Cupertino-friendly structure.
  - Implement a **glass bottom tab bar** (single blur surface spanning width) driven by `navigationShell.goBranch(...)`.
  - Update `PixelNavIcon` so selected/unselected colors read correctly on translucent backgrounds.
- Convert priority screens/overlays to Cupertino-first:
  - Replace `Scaffold/AppBar` with `CupertinoPageScaffold` + `CupertinoNavigationBar`.
  - Replace Material controls with `CupertinoButton`, `CupertinoTextField`, `CupertinoActivityIndicator`.
  - Replace Material sheets/snackbars with Cupertino-style presentation + glass surfaces.

## Performance + quality gates
- Use blur on **small bounded regions** (tab bar, sheets, cards), avoid many `BackdropFilter`s in scrolling lists.
- Wrap large blurred widgets in `RepaintBoundary` when needed.
- Verify legibility in light/dark and with Reduce Transparency enabled.

## Acceptance checks
- Auth redirect flow still works (splash/login → shell).
- Tab switching feels native iOS; bottom bar looks glassy and remains responsive.
- Modal sheet(s) (user menu) render with glass surface + correct dismissal behavior.
- No obvious jank on tab switching or simple scrolls.