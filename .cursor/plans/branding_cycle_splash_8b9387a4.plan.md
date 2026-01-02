---
name: Branding cycle splash
overview: Add a reusable Flutter widget that cycles through branded logo/rectangle SVGs by color, and use it on a new splash route that shows first on app launch.
todos:
  - id: add-svg-assets
    content: Add `flutter_svg` dependency and declare `assets/branding/` in `pubspec.yaml`.
    status: completed
  - id: branding-cycle-widget
    content: Implement `BrandingCycleAnimation` widget that cycles logo/rectangle SVGs across the default color list with configurable timing.
    status: completed
    dependencies:
      - add-svg-assets
  - id: splash-screen
    content: Create `SplashScreen` that displays the `BrandingCycleAnimation` and navigates to `/` after a short delay.
    status: completed
    dependencies:
      - branding-cycle-widget
  - id: router-initial-splash
    content: Update `app_router.dart` to add `/splash` route and set `initialLocation` to `/splash`.
    status: completed
    dependencies:
      - splash-screen
---

# Reusable Branding Cycle Animation + Splash

## Goal

Create a **reusable animation widget** that cycles: `logo(color)` → `rectangle(color)` → `logo(nextColor)` → …, and show it on a **splash screen** that appears first at app startup.

## Decisions Locked In

- **Placement**: Splash screen (first screen on startup)
- **Assets**: Use existing **SVG** files in `assets/branding/` (add `flutter_svg`)

## Implementation Outline

### 1) Add SVG + assets wiring

- Update `[pubspec.yaml](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/pubspec.yaml)`:
- Add dependency: `flutter_svg`
- Add assets: `assets/branding/`

### 2) Implement reusable animation widget

- Add a new widget file, e.g. `[lib/widgets/branding_cycle_animation.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/branding_cycle_animation.dart)`.
- Widget API (proposed):
- `colors`: ordered list like `['blue','green','orange','purple','red','teal','yellow']`
- `stepDuration`: how long each state is shown
- `transitionDuration`: crossfade time between states
- `size` / `fit`
- Internals (proposed):
- Build an ordered sequence of asset paths:
    - `assets/branding/logo-<color>.svg`
    - `assets/branding/rectangle-<color>.svg`
- Cycle through the sequence on a timer and render via `AnimatedSwitcher` for a clean fade.

### 3) Add a splash screen that hosts the widget

- Create `[lib/screens/splash_screen.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/splash_screen.dart)`:
- Center the `BrandingCycleAnimation`
- After N seconds (or after a full cycle), navigate with `context.go('/')` so the user can’t “back” into splash.

### 4) Route splash first

- Update `[lib/routing/app_router.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart)`:
- Add a `GoRoute(path: '/splash', ...)`
- Set `initialLocation: '/splash'`

## Default Behavior