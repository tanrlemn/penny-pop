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
  final overlay = Overlay.of(context, rootOverlay: true);

  final reduceMotion = GlassAdaptive.reduceMotionOf(context);
  OverlayEntry? entry;

  entry = OverlayEntry(
    builder: (context) {
      final safe = MediaQuery.of(context).padding;
      // Position below the nav bar area so it doesn't fight the bottom tab bar.
      const navBarHeight = 44.0;
      final top = safe.top + navBarHeight + 12;

      return Positioned(
        left: 16,
        right: 16,
        top: top,
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
    final brightness = GlassAdaptive.brightnessOf(context);
    final textColor = brightness == Brightness.dark
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF111111);

    final child = GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          height: 1.2,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        child: Text(
          message,
          maxLines: 3,
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


