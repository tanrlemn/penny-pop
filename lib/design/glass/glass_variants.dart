import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/design/glass/glass_surface.dart';
import 'package:penny_pop_app/design/glass/glass_tokens.dart';
import 'package:penny_pop_app/design/glass/glass_variant.dart';

/// Preset “glass” surfaces so screens don’t hand-roll styling.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.height = 64,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.borderRadius = GlassTokens.radiusXl,
  });

  final Widget child;
  final double height;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: GlassSurface(
        variant: GlassVariant.bar,
        borderRadius: borderRadius,
        padding: padding,
        child: child,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = GlassTokens.paddingMd,
    this.borderRadius = GlassTokens.radiusLg,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.card,
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
  }
}


