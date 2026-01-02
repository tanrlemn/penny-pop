import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:penny_pop_app/design/glass/glass.dart';

/// Lightweight, Cupertino-friendly feedback (replacement for SnackBar).
///
/// Uses a single glass surface and auto-dismisses.
void showGlassToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context);

  final reduceMotion = GlassAdaptive.reduceMotionOf(context);
  OverlayEntry? entry;

  entry = OverlayEntry(
    builder: (context) {
      final safe = MediaQuery.of(context).padding;
      // Keep it above the bottom tab bar region.
      final bottom = safe.bottom + 90;

      return Positioned(
        left: 16,
        right: 16,
        bottom: bottom,
        child: IgnorePointer(
          child: _ToastSurface(
            message: message,
            reduceMotion: reduceMotion,
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  Timer(duration, () {
    entry?.remove();
    entry = null;
  });
}

class _ToastSurface extends StatelessWidget {
  const _ToastSurface({
    required this.message,
    required this.reduceMotion,
  });

  final String message;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final child = GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14, height: 1.2),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (reduceMotion) return child;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: 1,
      child: child,
    );
  }
}


