---
name: App icon + loading animation
overview: Set the iOS app icon to use assets/branding/app-icon.png and add a reusable Flutter loading widget that plays the assets/branding/penny-logo.json animation (Lottie) from the assets bundle.
todos:
  - id: pubspec-assets-deps
    content: Update pubspec.yaml to include assets/branding/, add lottie dependency, and configure flutter_launcher_icons (iOS only).
    status: completed
  - id: generate-ios-icons
    content: Run flutter_launcher_icons to regenerate ios/Runner/Assets.xcassets/AppIcon.appiconset from assets/branding/app-icon.png.
    status: in_progress
    dependencies:
      - pubspec-assets-deps
  - id: add-loading-widget
    content: Create PennyLoadingIndicator widget using Lottie.asset('assets/branding/penny-logo.json').
    status: pending
    dependencies:
      - pubspec-assets-deps
  - id: demo-in-main
    content: Update lib/main.dart to demonstrate PennyLoadingIndicator in the UI (minimal, reversible).
    status: pending
    dependencies:
      - add-loading-widget
---

# iOS App Icon + Penny Loading Animation

## Goals

- **App icon (iOS only)**: Generate/update iOS app icon assets from `assets/branding/app-icon.png`.
- **Animation**: Add a reusable loading widget that plays `assets/branding/penny-logo.json`.

## Constraints / Notes

- iOS native Launch Screen (`ios/Runner/Base.lproj/LaunchScreen.storyboard`) must be **static**; we’ll implement the animation **inside Flutter** as a reusable loading indicator widget.
- Your project currently has no `android/` folder, so we’ll scope icon generation to **iOS only**.

## Implementation Plan

### 1) Add assets + dependencies

- Update [`pubspec.yaml`](pubspec.yaml):
- Add the branding directory as assets:
    - `assets/branding/`
- Add runtime dependency:
    - `lottie` (to render `penny-logo.json`)
- Add dev dependency + config:
    - `flutter_launcher_icons`
    - `flutter_launcher_icons` config with `ios: true` and `image_path: assets/branding/app-icon.png`

### 2) Generate iOS app icon set

- Run icon generation:
- `dart run flutter_launcher_icons`
- This will update the iOS asset catalog in [`ios/Runner/Assets.xcassets/AppIcon.appiconset`](ios/Runner/Assets.xcassets/AppIcon.appiconset).

### 3) Create reusable loading widget

- Add a widget file, e.g. [`lib/widgets/penny_loading_indicator.dart`](lib/widgets/penny_loading_indicator.dart):
- `PennyLoadingIndicator` renders `Lottie.asset('assets/branding/penny-logo.json')`
- Provide simple customization knobs (size, repeat, optional semantics label)

### 4) Wire it into the app (minimal demo)

- Update [`lib/main.dart`](lib/main.dart):
- Keep your current app structure, but replace the counter body with a small demo showing `PennyLoadingIndicator` (so you can immediately see it render).
- (Optional) Leave a TODO comment where you’ll use it as a real loading indicator later.

## Validation

- **Build**: `flutter build ios` succeeds.
- **Icon**: iOS simulator/device shows the new icon.
- **Animation**: App runs and `PennyLoadingIndicator` displays the penny animation from assets without runtime asset errors.

## Files Likely Touched

- [`pubspec.yaml`](pubspec.yaml)
- [`lib/main.dart`](lib/main.dart)
- [`lib/widgets/penny_loading_indicator.dart`](lib/widgets/penny_loading_indicator.dart) (new)
- [`ios/Runner/Assets.xcassets/AppIcon.appiconset/*`](ios/Runner/Assets.xcassets/AppIcon.appiconset) (generated)