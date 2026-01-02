---
name: iOS glass system
overview: Convert the app to a Cupertino-first (iOS-only) UI and apply a consistent “Apple glass” design system across navigation, overlays, content surfaces, and controls.
todos:
  - id: add-glass-design-system
    content: Create `lib/design/glass/` with tokens + reusable glass widgets (surfaces, controls, feedback, background), including reduce-transparency fallback.
    status: pending
  - id: switch-to-cupertino-app-router
    content: Update `PennyPopApp` to use `CupertinoApp.router` and set a global `CupertinoThemeData` aligned to the glass tokens.
    status: pending
  - id: cupertino-pages-in-router
    content: Update `app_router.dart` route definitions to use `pageBuilder` with Cupertino pages/transitions so navigation is iOS-native.
    status: pending
  - id: glass-shell-tabbar
    content: Refactor `AppShell` to a Cupertino-friendly shell and implement a glass bottom tab bar driven by `StatefulNavigationShell`.
    status: pending
  - id: convert-screens-and-overlays
    content: Convert screens and overlays from Material to Cupertino-first and apply glass components everywhere (login, splash, tabs, settings subtree, user menu sheet).
    status: pending
---

# Cupertino-first Apple-glass UI rollout

We’ll convert the app from a Material-first structure to a **Cupertino-first iOS app** and introduce a small, reusable **glass styling system** (blur + translucency + subtle border + depth) that we apply consistently to **navigation chrome, overlays, content surfaces, and controls**.

## Approach

- **Cupertino-first**: switch the root widget from `MaterialApp.router` to `CupertinoApp.router` and convert screens from `Scaffold/AppBar/*Button/TextField` to Cupertino equivalents.
- **Reusable glass system**: define a small set of design tokens and widgets (`GlassSurface`, `GlassButton`, `GlassSheet`, etc.) so we don’t hand-style each screen.
- **Router stays**: keep `go_router`, but update route building so pages use **Cupertino page transitions** (and don’t silently fall back to Material pages).

## Key files we’ll update

- App root + theming
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/main.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/main.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/main.dart )
- Routing (Cupertino pages)
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart )
- Shell / bottom navigation (glass)
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/shell/app_shell.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/pixel_nav_icon.dart )
- Overlays (glass sheet + dialog/toast replacements)
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart )
- Screens (convert from Material)
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/login_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/login_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/login_screen.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/splash_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/splash_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/splash_screen.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/home_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/home_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/home_screen.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/settings_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/settings_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/settings_screen.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/me_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/me_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/me_screen.dart )
- [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/add_partner_screen.dart`](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/add_partner_screen.dart)( /Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/add_partner_screen.dart )
- (and the other tab screens: `activity_screen.dart`, `pods_screen.dart`, `coach_screen.dart`)

## New “glass system” module

Add a small design module under `lib/design/glass/`:

- `glass_tokens.dart`
- Defines blur sigma, opacities, corner radii, border widths, and dynamic colors for **light/dark**.
- Includes an accessibility hook: if `MediaQuery.of(context).accessibilityFeatures.reduceTransparency` is true, reduce/disable blur and increase opacity.
- `glass_surface.dart`
- A reusable surface that applies `ClipRRect` + `BackdropFilter` + translucent fill + subtle border + soft shadow.
- Variants for **nav bars**, **cards/tiles**, and **sheets**.
- `glass_controls.dart`
- `GlassButton` (primary/secondary) built on `CupertinoButton` but with consistent glass visuals.
- `GlassTextField` wrapper around `CupertinoTextField` with padding, radius, and iOS-like placeholder/label handling.
- `glass_feedback.dart`
- `showGlassToast(...)` (Overlay-based, lightweight) to replace `ScaffoldMessenger` snackbars.
- `showGlassAlert(...)` using `CupertinoAlertDialog` (and glassy styling where feasible).
- `glass_background.dart`
- App-level background (subtle gradient + optional noise) so glass has something to “sit on.”

## Cupertino app + routing changes

- Switch root to `CupertinoApp.router` and apply a single `CupertinoThemeData` (SF Pro default typography, iOS dynamic colors).
- Update `go_router` routes in `app_router.dart` to use **Cupertino pages** via `pageBuilder` (instead of `builder`) so transitions and navigation behavior are iOS-native.

## Shell (bottom nav) in glass

- Replace the current `Scaffold` + `BottomNavigationBar` in `AppShell` with a Cupertino-friendly structure:
- Content = `navigationShell`
- Bottom bar = a **glass** tab bar (likely `CupertinoTabBar`-like visuals, but driven by `navigationShell.goBranch(...)`).
- Keep using your `PixelNavIcon`, but ensure it pulls the correct icon color from the surrounding Cupertino icon theme (so selected/unselected states look right on translucent glass).

## Screen conversions (Material → Cupertino-first)

- Replace `Scaffold/AppBar` with `CupertinoPageScaffold` + `CupertinoNavigationBar`.
- Replace Material buttons/inputs/progress indicators:
- `FilledButton/OutlinedButton` → `GlassButton` / `CupertinoButton`
- `TextField` → `CupertinoTextField` (via `GlassTextField`)
- `CircularProgressIndicator` → `CupertinoActivityIndicator`
- Replace `ScaffoldMessenger` snackbars with `showGlassToast(...)` or `showGlassAlert(...)` where appropriate.
- Replace `RefreshIndicator` in `SettingsScreen` with `CustomScrollView` + `CupertinoSliverRefreshControl`.

## Bottom sheets / overlays

- Replace `showModalBottomSheet` usage (e.g. `showUserMenuSheet`) with a Cupertino-appropriate presentation:
- Use `showCupertinoModalPopup` (or `showCupertinoDialog` where appropriate)
- Render a custom `GlassSheet` surface with rounded top corners, drag handle, and blurred backdrop.

## Visual acceptance criteria

- **Nav + sheets + dialogs**: blurred, translucent, subtle border, iOS feel.
- **All screens**: consistent background + surface styling (no stray Material components).
- **Controls**: buttons and text fields match the same glass tokens.
- **Light/dark**: dynamic color correctness; legible text on translucent surfaces.

## Validation

- Run the app and visually check:
- Tab switching + auth redirects
- Login → app shell
- User menu sheet flows (menu → account → my info → invite partner)
- Error/confirmation feedback (toast/alert)