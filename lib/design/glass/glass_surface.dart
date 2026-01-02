import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/design/glass/glass_adaptive.dart';
import 'package:penny_pop_app/design/glass/glass_variant.dart';
import 'package:penny_pop_app/design/glass/glass_tokens.dart';
import 'package:penny_pop_app/design/glass/ios_system_material_backdrop.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.variant = GlassVariant.card,
    this.borderRadius = GlassTokens.radiusLg,
    this.blurSigma,
    this.tint,
    this.borderColor,
    this.borderWidth = GlassTokens.borderWidthHairline,
    this.padding = GlassTokens.paddingMd,
    this.shadows,
    this.adaptive = true,
  });

  final Widget child;
  final GlassVariant variant;
  final BorderRadius borderRadius;

  /// Requested blur sigma. If [adaptive] is true this can be clamped/disabled
  /// based on platform/accessibility.
  ///
  /// When null, uses [GlassTokens.blurSigmaFor] based on [variant].
  final double? blurSigma;

  /// If null, derived from [GlassTokens] and platform brightness.
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final List<BoxShadow>? shadows;

  /// When true, applies iOS-only gating + Reduce Transparency/Motion behavior.
  final bool adaptive;

  double _uniformCornerRadius(BorderRadius radius) {
    // Our design tokens use uniform radii. If callers pass a non-uniform
    // BorderRadius, pick the max so the native view remains safely clipped.
    final tl = radius.topLeft.x;
    final tr = radius.topRight.x;
    final bl = radius.bottomLeft.x;
    final br = radius.bottomRight.x;
    return <double>[tl, tr, bl, br].reduce((a, b) => a > b ? a : b);
  }

  IosSystemMaterialStyle _iosStyleForVariant(GlassVariant variant) {
    return switch (variant) {
      GlassVariant.bar => IosSystemMaterialStyle.ultraThin,
      GlassVariant.card => IosSystemMaterialStyle.regular,
      GlassVariant.sheet => IosSystemMaterialStyle.thick,
      GlassVariant.toast => IosSystemMaterialStyle.regular,
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = GlassAdaptive.brightnessOf(context);
    final reduceTransparency =
        adaptive ? GlassAdaptive.reduceTransparencyOf(context) : false;

    final requestedSigma = blurSigma ?? GlassTokens.blurSigmaFor(variant);

    final effectiveSigma = adaptive
        ? GlassAdaptive.effectiveBlurSigma(
            context,
            requestedSigma: requestedSigma,
          )
        : requestedSigma;

    final iosMaterialEnabled =
        (adaptive ? GlassAdaptive.blurEnabled(context) : true) &&
            effectiveSigma > 0 &&
            GlassAdaptive.isIOS;

    final blurIsActive = iosMaterialEnabled || effectiveSigma > 0;

    final effectiveTint = tint ??
        (reduceTransparency || !blurIsActive
            ? GlassTokens.reducedTransparencyTintFor(brightness, variant)
            : GlassTokens.overlayTintFor(brightness, variant));

    final effectiveBorderColor =
        borderColor ?? GlassTokens.borderColorFor(brightness, variant);

    final effectiveShadows =
        shadows ??
        (adaptive
            ? GlassTokens.shadowsFor(brightness, variant)
            : <BoxShadow>[]);

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

    final content = iosMaterialEnabled
        ? Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IosSystemMaterialBackdrop(
                  style: _iosStyleForVariant(variant),
                  cornerRadius: _uniformCornerRadius(borderRadius),
                ),
              ),
              surface,
            ],
          )
        : (effectiveSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveSigma,
                  sigmaY: effectiveSigma,
                ),
                child: surface,
              )
            : surface);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}


