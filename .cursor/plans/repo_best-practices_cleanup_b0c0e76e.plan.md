---
name: Repo best-practices cleanup
overview: Tighten config/secrets handling (no bundled .env), align iOS Google sign-in with platform config, stabilize tests, and add basic repo hygiene (docs + CI + gitignore) for a team-friendly Flutter repo.
todos:
  - id: remove-dotenv-asset
    content: Remove `.env.local` from Flutter assets, remove `flutter_dotenv`, and update `main.dart` + `Env` to use only `--dart-define`.
    status: completed
  - id: ios-google-plist
    content: Add `GIDClientID` to `ios/Runner/Info.plist` and simplify `AuthService` to not require GOOGLE_IOS_CLIENT_ID at runtime.
    status: completed
    dependencies:
      - remove-dotenv-asset
  - id: gitignore-ios-generated
    content: Update `.gitignore` and remove any committed iOS generated artifacts (Pods/ephemeral/Generated.xcconfig) from version control.
    status: completed
  - id: stabilize-tests
    content: Update widget tests to initialize Supabase before pumping `PennyPopApp` (and optionally prep for dependency injection).
    status: completed
    dependencies:
      - remove-dotenv-asset
  - id: add-ci
    content: Add GitHub Actions workflow to run format/analyze/test on PRs and main.
    status: completed
  - id: update-readme
    content: Replace template README with real setup instructions and `--dart-define-from-file` example.
    status: completed
    dependencies:
      - remove-dotenv-asset
      - ios-google-plist
      - gitignore-ios-generated
---

# Best-practices hardening plan (iOS-only, no bundled .env)

## Goals

- Remove the risk of shipping `.env` contents inside the app bundle.
- Make auth/config more idiomatic for iOS Flutter (Google Sign-In configured via iOS plist, not runtime env).
- Improve repeatability: tests that don’t depend on global state surprises, and CI to enforce formatting/analyze/tests.
- Clean up repo hygiene so generated artifacts (Pods/ephemeral) don’t live in git.

## Scope decisions (already confirmed)

- **Platform**: iOS-only (for the next 1–2 months)
- **Config**: **no `.env` files bundled**; use `--dart-define` / `--dart-define-from-file`.

## Implementation steps

### 1) Stop bundling `.env.local` and remove `flutter_dotenv`

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/pubspec.yaml`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/pubspec.yaml)
- Remove `flutter_dotenv` dependency.
- Remove `.env.local` from `flutter/assets`.
- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/main.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/main.dart)
- Delete the `dotenv.load()` block.
- Keep the existing “fail fast” check for missing Supabase values.
- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/config/env.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/config/env.dart)
- Remove `flutter_dotenv` import.
- Read config only from `const String.fromEnvironment(...)`.
- Since iOS-only: drop `googleWebClientId` (unless you explicitly need it later).

### 2) Make Google Sign-In iOS configuration live in `Info.plist` (not Dart env)

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/ios/Runner/Info.plist`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/ios/Runner/Info.plist)
- Add `GIDClientID` using the client id derived from your existing URL scheme.
    - Current scheme: `com.googleusercontent.apps.672906493874-8lv37qa7ni7qc8b2essespn1b3fn7cg7`
    - Derived client id: `672906493874-8lv37qa7ni7qc8b2essespn1b3fn7cg7.apps.googleusercontent.com`
- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/auth/auth_service.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/auth/auth_service.dart)
- Remove the runtime requirement for `GOOGLE_IOS_CLIENT_ID`.
- Construct `GoogleSignIn()` without passing `clientId` (let iOS use `Info.plist`).

### 3) Fix repo hygiene for iOS (Pods and generated files)

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/.gitignore`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/.gitignore)
- Add standard ignores for iOS generated artifacts (at minimum `ios/Pods/`, and typically `ios/Flutter/Generated.xcconfig`, `ios/Flutter/ephemeral/`, `ios/.symlinks/`).
- Remove any currently-committed generated artifacts from git history (one-time cleanup)
- If `ios/Pods/` and `ios/Flutter/Generated.xcconfig` are checked in, remove them from the repo and rely on `pod install` / `flutter pub get` to regenerate.

### 4) Stabilize widget tests (avoid uninitialized global Supabase)

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/test/widget_test.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/test/widget_test.dart)
- Ensure `Supabase.initialize(...)` occurs before pumping `PennyPopApp`, using dummy-but-valid values (no network requests needed for these tests).
- Longer-term (optional): refactor [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/app/penny_pop_app.dart) + [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/routing/app_router.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/routing/app_router.dart) to accept an injected `SupabaseClient` for easier testing.

### 5) Add CI (if the repo is on GitHub)

- Add `.github/workflows/ci.yml` running:
- `flutter pub get`
- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`

### 6) Replace template README with real onboarding

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/README.md`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/README.md)
- Required `--dart-define` keys (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`).
- Recommended local workflow using `--dart-define-from-file` (add a checked-in `dart_defines.example.json` with placeholders).
- iOS setup notes (CocoaPods, signing, Google Sign-In plist keys).

## Notes / rationale for key changes

- Bundling `.env.local` as an asset is convenient but increases the chance that “something secret” ends up shipped. Moving to `--dart-define(-from-file)` keeps local convenience while avoiding embedding a dotenv file in the bundle.
- iOS-only Google Sign-In is typically configured via iOS project settings (`Info.plist` / URL scheme). Your `Info.plist` already includes the URL scheme; adding `GIDClientID` makes the setup more canonical and removes the need for runtime env.