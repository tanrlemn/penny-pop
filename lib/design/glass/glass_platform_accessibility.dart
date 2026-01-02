import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-backed accessibility flags that Flutter does not expose directly.
///
/// iOS: uses `UIAccessibility.isReduceTransparencyEnabled` (via MethodChannel)
/// and listens for changes (via EventChannel).
abstract final class GlassPlatformAccessibility {
  static const MethodChannel _methodChannel =
      MethodChannel('penny_pop/accessibility');
  static const EventChannel _reduceTransparencyChannel =
      EventChannel('penny_pop/accessibility_reduce_transparency');

  static final ValueNotifier<bool> reduceTransparencyEnabled =
      ValueNotifier<bool>(false);

  static StreamSubscription<dynamic>? _reduceTransparencySub;

  static Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final initial = await _methodChannel.invokeMethod<bool>(
        'getReduceTransparencyEnabled',
      );
      reduceTransparencyEnabled.value = initial ?? false;
    } catch (_) {
      // Safe fallback: treat as disabled.
      reduceTransparencyEnabled.value = false;
    }

    _reduceTransparencySub ??= _reduceTransparencyChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      if (event is bool) reduceTransparencyEnabled.value = event;
    });
  }
}


