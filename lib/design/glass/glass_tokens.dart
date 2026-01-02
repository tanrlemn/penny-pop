import 'package:flutter/widgets.dart';

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

  /// Default glass tint. Keep low opacity when blur is enabled.
  static Color tintFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x66000000) // ~40% black
        : const Color(0x66FFFFFF); // ~40% white
  }

  /// Tint when Reduce Transparency is enabled (no blur). More opaque so content
  /// stays legible but still “glassy”.
  static Color reducedTransparencyTintFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0xCC000000) // ~80% black
        : const Color(0xE6FFFFFF); // ~90% white
  }

  static Color borderColorFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color(0x1FFFFFFF) // ~12% white
        : const Color(0x26FFFFFF); // ~15% white
  }

  static List<BoxShadow> shadowsFor(Brightness brightness) {
    // Very subtle depth; keep it minimal so it reads like iOS material.
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF000000).withValues(
          alpha: brightness == Brightness.dark ? 0.35 : 0.12,
        ),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ];
  }
}


