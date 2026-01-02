import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/design/glass/glass_variant.dart';

/// Design tokens for Penny Pop’s “glass” surfaces.
///
/// These are intentionally small and opinionated so the look stays consistent.
abstract final class GlassTokens {
  static const double borderWidthHairline = 1.0;
  static const double blurSigma = 18.0;

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(24));

  static const EdgeInsets paddingSm = EdgeInsets.all(10);
  static const EdgeInsets paddingMd = EdgeInsets.all(12);

  /// Blur strength by surface type (used by the Flutter fallback, and as a
  /// general “thickness” hint).
  static double blurSigmaFor(GlassVariant variant) {
    return switch (variant) {
      GlassVariant.bar => 14.0,
      GlassVariant.card => 18.0,
      GlassVariant.sheet => 26.0,
      GlassVariant.toast => 18.0,
    };
  }

  /// Overlay tint used when blur/material is active.
  ///
  /// This is intentionally *variant-specific* so sheets read thicker (especially
  /// in light mode) while bars remain airy.
  static Color overlayTintFor(Brightness brightness, GlassVariant variant) {
    if (brightness == Brightness.dark) {
      return switch (variant) {
        GlassVariant.bar => const Color(0x52000000), // ~32% black
        GlassVariant.card => const Color(0x66000000), // ~40% black
        GlassVariant.sheet => const Color(0x80000000), // ~50% black
        GlassVariant.toast => const Color(0x73000000), // ~45% black
      };
    }

    // Light mode: make sheets noticeably thicker; cards slightly thicker than
    // before; keep bars lighter.
    return switch (variant) {
      GlassVariant.bar => const Color(0x4DFFFFFF), // ~30% white
      GlassVariant.card => const Color(0x73FFFFFF), // ~45% white
      GlassVariant.sheet => const Color(0xB3FFFFFF), // ~70% white
      GlassVariant.toast => const Color(0x99FFFFFF), // ~60% white
    };
  }

  /// Tint when Reduce Transparency is enabled (no blur). More opaque so content
  /// stays legible but still “glassy”.
  static Color reducedTransparencyTintFor(Brightness brightness, GlassVariant variant) {
    if (brightness == Brightness.dark) {
      return switch (variant) {
        GlassVariant.bar => const Color(0xB3000000), // ~70% black
        GlassVariant.card => const Color(0xCC000000), // ~80% black
        GlassVariant.sheet => const Color(0xE6000000), // ~90% black
        GlassVariant.toast => const Color(0xD9000000), // ~85% black
      };
    }

    return switch (variant) {
      GlassVariant.bar => const Color(0xD9FFFFFF), // ~85% white
      GlassVariant.card => const Color(0xE6FFFFFF), // ~90% white
      GlassVariant.sheet => const Color(0xF2FFFFFF), // ~95% white
      GlassVariant.toast => const Color(0xEEFFFFFF), // ~93% white
    };
  }

  static Color borderColorFor(Brightness brightness, GlassVariant variant) {
    // Keep the edge subtle but slightly stronger on thicker surfaces.
    if (brightness == Brightness.dark) {
      return switch (variant) {
        GlassVariant.bar => const Color(0x1AFFFFFF),
        GlassVariant.card => const Color(0x1FFFFFFF),
        GlassVariant.sheet => const Color(0x26FFFFFF),
        GlassVariant.toast => const Color(0x22FFFFFF),
      };
    }

    // Light mode: use a faint dark stroke; white strokes on a white-ish sheet
    // often disappear.
    return switch (variant) {
      GlassVariant.bar => const Color(0x1A000000),
      GlassVariant.card => const Color(0x14000000),
      GlassVariant.sheet => const Color(0x1F000000),
      GlassVariant.toast => const Color(0x1A000000),
    };
  }

  static List<BoxShadow> shadowsFor(Brightness brightness, GlassVariant variant) {
    // Very subtle depth; keep it minimal so it reads like iOS material.
    final blur = switch (variant) {
      GlassVariant.bar => 16.0,
      GlassVariant.card => 18.0,
      GlassVariant.sheet => 24.0,
      GlassVariant.toast => 18.0,
    };
    final y = switch (variant) {
      GlassVariant.bar => 8.0,
      GlassVariant.card => 10.0,
      GlassVariant.sheet => 12.0,
      GlassVariant.toast => 10.0,
    };
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF000000).withValues(
          alpha: brightness == Brightness.dark ? 0.35 : 0.12,
        ),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }
}


