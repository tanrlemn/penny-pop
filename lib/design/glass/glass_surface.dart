import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/design/glass/glass_adaptive.dart';
import 'package:penny_pop_app/design/glass/glass_tokens.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = GlassTokens.radiusLg,
    this.blurSigma = GlassTokens.blurSigma,
    this.tint,
    this.borderColor,
    this.borderWidth = GlassTokens.borderWidthHairline,
    this.padding = GlassTokens.paddingMd,
    this.shadows,
    this.adaptive = true,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Requested blur sigma. If [adaptive] is true this can be clamped/disabled
  /// based on platform/accessibility.
  final double blurSigma;

  /// If null, derived from [GlassTokens] and platform brightness.
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final List<BoxShadow>? shadows;

  /// When true, applies iOS-only gating + Reduce Transparency/Motion behavior.
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    final brightness = GlassAdaptive.brightnessOf(context);
    final reduceTransparency =
        adaptive ? GlassAdaptive.reduceTransparencyOf(context) : false;

    final effectiveTint = tint ??
        (reduceTransparency
            ? GlassTokens.reducedTransparencyTintFor(brightness)
            : GlassTokens.tintFor(brightness));

    final effectiveBorderColor =
        borderColor ?? GlassTokens.borderColorFor(brightness);

    final effectiveSigma = adaptive
        ? GlassAdaptive.effectiveBlurSigma(
            context,
            requestedSigma: blurSigma,
          )
        : blurSigma;

    final effectiveShadows =
        shadows ?? (adaptive ? GlassTokens.shadowsFor(brightness) : <BoxShadow>[]);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveTint,
        borderRadius: borderRadius,
        border: Border.all(color: effectiveBorderColor, width: borderWidth),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: effectiveSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveSigma,
                  sigmaY: effectiveSigma,
                ),
                child: surface,
              )
            : surface,
      ),
    );
  }
}


