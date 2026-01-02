# Penny Pop

Flutter (iOS) app for Penny Pop.

## Requirements

- Flutter SDK (matches the repo’s `environment:` constraints in `pubspec.yaml`)
- Xcode + CocoaPods (for iOS builds)

## Configuration (required)

This app uses build-time config via `--dart-define` / `--dart-define-from-file`.

Required keys:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

### Local setup (recommended)

1. Copy the example file:

```bash
cp dart_defines.example.json dart_defines.json
```

2. Fill in `dart_defines.json` with your Supabase values.

3. Run:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

## Security: family-only access

This app is intentionally locked to a single household (family use only).

- The backend `ensure_active_household()` RPC is configured to **only** return household `4b7c62d7-7584-4665-a1e7-991700d4d30c` for users who are members of that household.
- The `sync-pods` Edge Function additionally refuses to sync unless the household is that same id.

Recommended:

- In Supabase Auth (hosted project), disable public signups (invite-only).
- For local dev, `supabase/config.toml` sets `auth.enable_signup = false`.

## Google Sign-In (iOS)

Google Sign-In is configured via iOS project settings (not Dart env).

Ensure [`ios/Runner/Info.plist`](ios/Runner/Info.plist) contains:

- `GIDClientID` set to your iOS OAuth client id (`...apps.googleusercontent.com`)
- `CFBundleURLTypes` includes the reversed client id URL scheme (`com.googleusercontent.apps....`)

## Common commands

```bash
flutter pub get
flutter analyze
flutter test
```
