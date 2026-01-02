import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/svg.dart';
import 'package:penny_pop_app/widgets/branding_cycle_animation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minimumDisplayDuration = const Duration(milliseconds: 1200),
  });

  final Duration minimumDisplayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _startedLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoading) return;
    _startedLoading = true;
    _loadAndGoHome();
  }

  Future<void> _loadAndGoHome() async {
    // "Loaded" in this context = key branded SVG assets are decoded and cached.
    const colors = [
      'blue',
      'green',
      'orange',
      'purple',
      'red',
      'teal',
      'yellow',
    ];

    final assets = <String>[
      for (final c in colors) 'assets/branding/logo-$c.svg',
      for (final c in colors) 'assets/branding/rectangle-$c.svg',
    ];

    try {
      await Future.wait([
        Future.wait(assets.map((path) => SvgAssetLoader(path).loadBytes(context))),
        Future.delayed(widget.minimumDisplayDuration),
      ]);
    } catch (_) {
      // If precaching fails for any reason, don't block the user from entering the app.
    }

    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: BrandingCycleAnimation(),
        ),
      ),
    );
  }
}


