import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:penny_pop_app/design/glass/glass_platform_accessibility.dart';

/// Central place for “Apple glass” feature gating and accessibility-driven
/// adjustments.
///
/// Rules encoded here:
/// - Glass blur effects are iOS-only (fallback to opaque/tinted elsewhere).
/// - Reduce Transparency disables blur (fallback remains intentional).
/// - Reduce Motion can tone down blur intensity (optional).
abstract final class GlassAdaptive {
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static Brightness brightnessOf(BuildContext context) {
    final inheritedCupertino =
        context.dependOnInheritedWidgetOfExactType<InheritedCupertinoTheme>();
    final cupertinoBrightness = inheritedCupertino?.theme.data.brightness;
    if (cupertinoBrightness != null) {
      return cupertinoBrightness;
    }
    return MediaQuery.platformBrightnessOf(context);
  }

  static bool reduceTransparencyOf(BuildContext context) {
    // Flutter does not expose iOS “Reduce Transparency” directly; we bridge it
    // via platform channels.
    return GlassPlatformAccessibility.reduceTransparencyEnabled.value;
  }

  static bool reduceMotionOf(BuildContext context) {
    final features = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return MediaQuery.of(context).disableAnimations ||
        features.disableAnimations ||
        features.reduceMotion ||
        features.accessibleNavigation;
  }

  /// Returns whether blur is allowed at all for this context.
  static bool blurEnabled(BuildContext context) {
    if (!isIOS) return false;
    if (reduceTransparencyOf(context)) return false;
    return true;
  }

  static double effectiveBlurSigma(
    BuildContext context, {
    required double requestedSigma,
    double reduceMotionMultiplier = 0.8,
  }) {
    if (!blurEnabled(context)) return 0;
    if (requestedSigma <= 0) return 0;
    if (!reduceMotionOf(context)) return requestedSigma;
    return requestedSigma * reduceMotionMultiplier;
  }
}


