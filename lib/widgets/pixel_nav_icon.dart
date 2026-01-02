import 'package:flutter/material.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';

class PixelNavIcon extends StatelessWidget {
  const PixelNavIcon(
    this.assetPath, {
    super.key,
    this.size = 24,
    this.semanticLabel,
  });

  final String assetPath;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return PixelIcon(
      assetPath,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}


