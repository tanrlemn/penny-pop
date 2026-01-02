---
name: Cupertino glass rollout
overview: Convert the app to a Cupertino-first iOS UI and introduce a small reusable glass design system (blur + tint + hairline border + depth), applying it first to the 4-tab shell and key overlays/surfaces.
todos:
  - id: add-glass-design-system
    content: Create `lib/design/glass/` tokens + `GlassSurface` (blur+tint+hairline border) with reduce-transparency + reduce-motion fallbacks, plus presets (bar/card/sheet) and an adaptive helper.
    status: completed
  - id: switch-to-cupertino-app
    content: Update `PennyPopApp` to use `CupertinoApp.router` and set `CupertinoThemeData` (light/dark) aligned to glass tokens.
    status: completed
    dependencies:
      - add-glass-design-system
  - id: glass-shell-tabbar
    content: Refactor `AppShell` to a Cupertino-friendly layout and implement a glass bottom tab bar driving `StatefulNavigationShell`; tune `PixelNavIcon` coloring for selected/unselected states.
    status: completed
    dependencies:
      - add-glass-design-system
      - switch-to-cupertino-app
  - id: cupertino-pages-router
    content: Update `createAppRouter` routes to use `pageBuilder` with Cupertino page transitions for the shell and the 1–2 most common push routes first; expand to the rest once the frame is stable.
    status: completed
    dependencies:
      - switch-to-cupertino-app
  - id: convert-screens-overlays
    content: Convert key screens/overlays from Material to Cupertino-first (login/splash + tab screens as needed + `user_menu_sheet.dart`), replacing Material sheets/snackbars with Cupertino/glass equivalents.
    status: completed
    dependencies:
      - glass-shell-tabbar
---

# Cupertino-first “Liquid Glass” rollout (iOS-only)

## Goals

- Make the app feel like Apple’s material-driven “glass”: **real blur + subtle tint + hairline border + layered depth**, with good legibility.
- Move to a **Cupertino-first** widget stack so navigation, typography, and platform behaviors match iOS expectations.
- Keep the existing **4-tab shell** (Overview/Pods/Guide/Transactions) and restyle/convert it.

## Global rules (to prevent drift)

- One blur surface per region:
- Bottom bar = single `GlassSurface`
- Sheets = single `GlassSurface`
- Cards = ok, but avoid nested glass-in-glass unless there’s a strong reason
- iOS-only enforcement:
- Gate glass blur/material effects behind `defaultTargetPlatform == TargetPlatform.iOS` so other platforms fall back to opaque/tinted surfaces (even if you’re iOS-only today, this prevents accidental cross-platform regressions later).
- Keyboard behavior (default):
- Bottom glass bar **lifts above the keyboard** (keep available). We can add a per-screen override later if a full-form screen wants to hide it.

## Key files we’ll touch

- App root/theming: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart)
- Routing/transitions: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)
- Shell/tab bar: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart)
- Icons in nav: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart)
- Overlays: [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart)(/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart)
- Screens (convert as needed): `lib/screens/*.dart`

## Implementation outline

- Glass module
- Structure:
- `glass_tokens.dart`
- `glass_surface.dart`
- `glass_variants.dart` (presets: bar/card/sheet)
- `glass_adaptive.dart` (accessibility-driven adjustments: reduce transparency + reduce motion)
- `GlassSurface`: `ClipRRect` + `BackdropFilter` + tint + 1px border.
- Accessibility/system “Apple feel” requirements:
- Reduce Transparency: when `MediaQuery.accessibilityFeatures.reduceTransparency` is true, reduce/disable blur and raise tint opacity so surfaces still look intentional.
- Reduce Motion: when `MediaQuery.disableAnimations` (and/or related accessibility flags) is true, tone down motion (and optionally clamp blur sigma) and avoid fancy fades/parallax.
- Dynamic Type + legibility: use `CupertinoTheme.of(context).textTheme` styles; enforce `maxLines` + `overflow` on tab labels; ensure selected/unselected icon contrast on tinted glass.
- Safe area + keyboard: bottom glass bar must respect `SafeArea(bottom: true)` and lift above the keyboard by default.
- App root
- Switch app root to `CupertinoApp.router`.
- Provide a global `CupertinoThemeData` aligned to glass tokens (light/dark), keep `ThemeMode.system`.
- Ensure existing `GoRouter` integration stays intact.
- Avoid losing app-wide defaults (e.g., if/when you add locales/delegates later, keep them wired through the root app).
- Routing (go_router)
- Update `go_router` routes to use **Cupertino pages/transitions**.
- Page type (consistency rule): use `CupertinoPage` for pushes (or `CustomTransitionPage` that exactly matches Cupertino), and avoid mixing Material transitions once the root switches.
- Keep churn minimal at first: update the **shell** plus the **1–2 most common push routes**, then expand once the frame is stable.
- Shell (AppShell + bottom bar)
- Keep `StatefulShellRoute.indexedStack` / `navigationShell.goBranch(...)` as the only tab navigation source of truth (avoid `CupertinoTabScaffold`’s built-in tab stacks).
- Replace `Scaffold` + `BottomNavigationBar` with a Cupertino-friendly structure:
- `CupertinoPageScaffold`
- `child: Stack(...)`
    - content: `navigationShell`
    - overlay: positioned bottom glass tab bar (so blur “catches” content behind it)
- Implement a **glass bottom tab bar** (single bounded blur surface) driven by `navigationShell.goBranch(...)`.
- Update `PixelNavIcon` so selected/unselected colors read correctly on translucent backgrounds.
- Optional: add a subtle selected emphasis (slightly stronger opacity or a very light glow/shadow), kept minimal.
- Screens + overlays
- Convert priority screens/overlays to Cupertino-first.
- Replace `Scaffold/AppBar` with `CupertinoPageScaffold` + `CupertinoNavigationBar`.
- Replace Material controls with `CupertinoButton`, `CupertinoTextField`, `CupertinoActivityIndicator`.
- Replace Material sheets/snackbars with Cupertino-style presentation + glass surfaces.

## Phase “done definitions” (exit checks)

- Glass module done:
- One demo card + the bottom bar preset render somewhere (e.g., on an existing screen temporarily).
- Reduce Transparency ON: same surfaces render tinted/opaque (no blur) and still look intentional.
- App root done:
- App boots via `CupertinoApp.router`; light/dark themes still follow system; no broken auth redirects.
- Shell done:
- Tab switching works via `goBranch(index)`.
- Back behavior is correct within branches.
- Branch state preserved (scroll position + nested navigation state preserved when switching tabs away and back).
- Routing transitions done (initial pass):
- Shell + 1–2 common push routes use Cupertino-style transitions; no Material transitions show up.
- Overlays done:
- User menu sheet presents/dismisses correctly and uses a single glass surface.

## Performance + quality gates

- Use blur on **small bounded regions** (tab bar, sheets, cards), avoid many `BackdropFilter`s in scrolling lists.
- Wrap large blurred widgets in `RepaintBoundary` when needed.
- Verify legibility in light/dark and with Reduce Transparency enabled.
- Ensure blur remains stable when content scrolls under the glass bar (no clipping/jitter).

## Acceptance checks

- Auth redirect flow still works (splash/login → shell).
- Tab switching feels native iOS; bottom bar looks glassy and remains responsive.
- Modal sheet(s) (user menu) render with glass surface + correct dismissal behavior.
- Reduce Transparency ON: surfaces become tinted/non-blurred but still look intentional.
- Reduce Motion ON: animations are toned down; no “floaty” transitions.
- Dark mode: tab icons/labels remain readable on the tinted glass bar.