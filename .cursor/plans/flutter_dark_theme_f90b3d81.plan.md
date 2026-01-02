---
name: Flutter dark theme
overview: Add a proper Material 3 dark theme and wire the app to follow the device’s light/dark setting. Update the Google sign-in button to use a dark variant when the app is in dark mode.
todos:
  - id: app-themes
    content: "Implement `theme`, `darkTheme`, and `themeMode: ThemeMode.system` in `PennyPopApp` using Material 3 color schemes from the existing seed color."
    status: completed
  - id: login-google-button
    content: Update `LoginScreen` Google button styling to use a dark variant in dark mode and remove hard-coded light colors.
    status: completed
    dependencies:
      - app-themes
  - id: smoke-check
    content: Smoke-check light vs dark on simulator/emulator and verify Login button readability/contrast.
    status: completed
    dependencies:
      - login-google-button
---

# System dark mode + Google dark button

## Goal

- Make the app support **true dark mode** and **follow the device setting** (`ThemeMode.system`).
- Ensure the **Login** screen’s “Continue with Google” button has a **dark variant** in dark mode (per your preference).

## Changes

### 1) Add light + dark themes at the app root

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/app/penny_pop_app.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/app/penny_pop_app.dart)
- Keep your existing seed color (`Colors.deepPurple`) but create **two** color schemes:
    - `ColorScheme.fromSeed(..., brightness: Brightness.light)`
    - `ColorScheme.fromSeed(..., brightness: Brightness.dark)`
- Set:
    - `theme:` using the light scheme
    - `darkTheme:` using the dark scheme
    - `themeMode: ThemeMode.system`

### 2) Fix hard-coded light colors on the Login screen

- Update [`/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/login_screen.dart`](/Volumes/Crucial%20X10/other-work/Penny%20Pixel%20Pop/penny_pop_app/lib/screens/login_screen.dart)
- Replace the current hard-coded button colors:
    - `backgroundColor: Colors.white`
    - `foregroundColor: Colors.black87`
- With conditional styling based on `Theme.of(context).brightness`:
    - **Light mode**: keep the current white Google button
    - **Dark mode**: use a dark variant (dark background + white text + appropriate border)
- Ensure the loading spinner (`CircularProgressIndicator`) also stays visible by setting its `color` to match the button foreground.

## Acceptance checks

- On a device/simulator:
- With system appearance **Light**: app uses light theme.
- With system appearance **Dark**: app uses dark theme (scaffold/app bars/bottom nav look correct).
- On Login: Google button switches to the dark variant in dark mode and remains readable/accessible.