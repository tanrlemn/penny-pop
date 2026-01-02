import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// iOS-only platform view that renders a `UIVisualEffectView` system material.
///
/// This is the closest approximation to Apple’s “Liquid Glass” material we can
/// get from Flutter while still composing Flutter content on top.
enum IosSystemMaterialStyle {
  ultraThin,
  thin,
  regular,
  thick,
  chrome,
}

class IosSystemMaterialBackdrop extends StatelessWidget {
  const IosSystemMaterialBackdrop({
    super.key,
    required this.style,
    required this.cornerRadius,
  });

  final IosSystemMaterialStyle style;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return UiKitView(
      viewType: 'penny_pop/system_material',
      creationParams: <String, dynamic>{
        'style': style.name,
        'cornerRadius': cornerRadius,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}


