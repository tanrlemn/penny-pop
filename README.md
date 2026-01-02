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
