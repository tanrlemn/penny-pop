import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandingCycleAnimation extends StatefulWidget {
  const BrandingCycleAnimation({
    super.key,
    this.colors = const [
      'blue',
      'green',
      'orange',
      'purple',
      'red',
      'teal',
      'yellow',
    ],
    this.stepDuration = const Duration(milliseconds: 650),
    this.transitionDuration = const Duration(milliseconds: 250),
    this.size = const Size(220, 220),
    this.fit = BoxFit.contain,
  });

  final List<String> colors;
  final Duration stepDuration;
  final Duration transitionDuration;
  final Size size;
  final BoxFit fit;

  @override
  State<BrandingCycleAnimation> createState() => _BrandingCycleAnimationState();
}

class _BrandingCycleAnimationState extends State<BrandingCycleAnimation> {
  Timer? _timer;
  int _stepIndex = 0;

  int get _stepCount => widget.colors.length * 2;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant BrandingCycleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepDuration != widget.stepDuration ||
        !listEquals(oldWidget.colors, widget.colors)) {
      _stepIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_stepCount == 0) return;

    _timer = Timer.periodic(widget.stepDuration, (_) {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex + 1) % _stepCount;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.colors.isEmpty) return const SizedBox.shrink();

    final colorIndex = _stepIndex ~/ 2;
    final isLogo = _stepIndex.isEven;

    final color = widget.colors[colorIndex];
    final assetPath = isLogo
        ? 'assets/branding/logo-$color.svg'
        : 'assets/branding/rectangle-$color.svg';

    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: AnimatedSwitcher(
        duration: widget.transitionDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: SvgPicture.asset(
          assetPath,
          key: ValueKey(assetPath),
          fit: widget.fit,
          semanticsLabel: isLogo ? 'Penny Pop logo ($color)' : 'Penny Pop ($color)',
        ),
      ),
    );
  }
}


