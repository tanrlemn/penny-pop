import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a monochrome pixel SVG that follows the current [IconTheme].
///
/// - Uses [IconTheme.of] color so selected/unselected states work naturally.
/// - Uses a crisp-edge SVG (`shape-rendering="crispEdges"`) for pixel look.
class PixelIcon extends StatelessWidget {
  const PixelIcon(
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
    final color = IconTheme.of(context).color;

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}


