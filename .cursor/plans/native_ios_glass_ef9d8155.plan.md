---
name: Native iOS glass
overview: Replace the current Flutter-only blur+tint with an iOS-native system material blur (UIVisualEffectView) on iOS, while keeping a tuned Flutter fallback elsewhere, and introduce variants (bar/card/sheet/toast) so light-mode sheets get thicker/clearer legibility.
todos:
  - id: add-glass-variants
    content: Add `GlassVariant` + route token decisions (tint/blur/border/shadow) through variants.
    status: pending
  - id: ios-platform-material
    content: Implement iOS `UIVisualEffectView` platform view + Dart wrapper and use it inside `GlassSurface` when blur is enabled.
    status: pending
    dependencies:
      - add-glass-variants
  - id: tune-light-mode-sheets
    content: Increase sheet “thickness” in light mode via variant-specific overlay tint (and optional small foreground contrast tweak).
    status: pending
    dependencies:
      - add-glass-variants
  - id: apply-variants-appwide
    content: Update GlassBar/GlassCard and all direct `GlassSurface` uses (sheets/toasts) to pass the right `variant`.
    status: pending
    dependencies:
      - add-glass-variants
      - ios-platform-material
      - tune-light-mode-sheets
  - id: ios-verify
    content: Manually verify on iOS simulator/device (light + dark, Reduce Transparency on/off).
    status: pending
    dependencies:
      - apply-variants-appwide
---

# Native iOS “Liquid Glass” parity (best-effort)

## Goal

Make Penny Pop’s glass surfaces read like Apple’s system materials, especially fixing **light-mode readability** on sheets, by using **native iOS blur materials** and adding **variant-specific thickness**.

## Key reality check (so expectations are right)

- We can match the **system blur material** closely by using `UIVisualEffectView` on iOS.
- Apple’s “vibrancy” effect (automatic foreground legibility boosting) generally requires the **foreground content to live inside** a `UIVibrancyEffectView`. Flutter widgets can’t be inserted into that native view hierarchy directly, so we’ll approximate legibility with **variant thickness + overlay tint + optional text/shadow tweaks**.

## Implementation approach

### 1) Introduce material variants in Dart

- Add an enum like `GlassVariant { bar, card, sheet, toast }` and route styling through it.
- Update `GlassSurface` to take `variant` and map it to:
- **iOS native material style** (thin/regular/thick)
- **fallback tint/blur** for non‑iOS

Files:

- [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_surface.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_surface.dart)
- [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_tokens.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_tokens.dart)
- [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_variants.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_variants.dart)

### 2) iOS native blur via Platform View

- Add a small `UiKitView`-backed widget (e.g. `IosSystemMaterialBackdrop`) used by `GlassSurface` when:
- platform is iOS, and
- blur is enabled (`GlassAdaptive.blurEnabled(context)`)
- The native view will be a `UIVisualEffectView` with a configurable style:
- `bar` → ultra-thin or thin material
- `card/toast` → regular material
- `sheet` → thick material (this is the big readability win in light mode)
- Ensure the native view clips to the same corner radius (`layer.cornerRadius` + `clipsToBounds = true`) because Flutter clipping does not reliably clip platform views.

Files:

- New Dart wrapper under [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/)
- iOS registration + implementation:
- [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/ios/Runner/AppDelegate.swift](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/ios/Runner/AppDelegate.swift)
- New Swift files under [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/ios/Runner/](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/ios/Runner/)

### 3) Light-mode legibility tuning (still needed even with native blur)

- Add **variant-specific overlay tint** in Flutter (very subtle on bar/card, noticeably thicker on sheet) to mimic Apple’s “material thickness” feel.
- Optionally add a tiny, subtle shadow/contrast tweak for secondary text on glass (only where needed, and only in light mode).

Files:

- [/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_tokens.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_tokens.dart)
- (Optional helper) a small `glass_text.dart` under `lib/design/glass/`

### 4) Apply variants everywhere (since you selected “all glass”)

- Update wrappers:
- `GlassBar` → `variant: bar`
- `GlassCard` → `variant: card`
- Update direct `GlassSurface` usages that are “sheet-like”:
- user menu popup → `variant: sheet` ([/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/widgets/user_menu_sheet.dart))
- pod settings sheet → `variant: sheet` ([/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/pods_screen.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/screens/pods_screen.dart))
- toast → `variant: toast` ([/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_toast.dart](/Volumes/Crucial X10/other-work/Penny Pixel Pop/penny_pop_app/lib/design/glass/glass_toast.dart))

### 5) Validate on iOS (light + dark)

- Check:
- sheet header + secondary label readability in light mode
- border/shadow not too heavy
- Reduce Transparency path still looks intentional (blur disabled, more opaque tint)

## Output behavior by platform

- **iOS**: native system material blur + tuned overlay tint (closest to Apple).