import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:penny_pop_app/design/glass/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _continueWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Force account picker so users can switch accounts (family-only app).
      await AuthService.instance.signInWithGoogle(forceAccountChooser: true);
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = GlassAdaptive.brightnessOf(context);
    final isDark = brightness == Brightness.dark;

    // Google button: keep the standard white style in light mode, use a dark
    // variant in dark mode for contrast.
    final googleButtonBackground =
        isDark ? const Color(0xFF131314) : const Color(0xFFFFFFFF);
    final googleButtonForeground =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xDD000000);
    final googleButtonBorder =
        isDark ? const Color(0xFF8E918F) : const Color(0xFFDADCE0);

    final textTheme = CupertinoTheme.of(context).textTheme;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/logo-main.png',
                      width: 96,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to Penny Pop',
                      style: textTheme.navTitleTextStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Finance management for The Lemons.',
                      style: textTheme.textStyle.copyWith(
                        color: (isDark ? CupertinoColors.white : CupertinoColors.black)
                            .withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isLoading ? null : _continueWithGoogle,
                        child: DecoratedBox(
                          key: const ValueKey('googleSignInButton'),
                          decoration: BoxDecoration(
                            color: googleButtonBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: googleButtonBorder),
                          ),
                          child: Center(
                            child: _isLoading
                                ? CupertinoActivityIndicator(
                                    color: googleButtonForeground,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/branding/google-g.svg',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Continue with Google',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: googleButtonForeground,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sticking to your budget = reaching your goals.',
                      style: textTheme.textStyle.copyWith(
                        color: (isDark ? CupertinoColors.white : CupertinoColors.black)
                            .withValues(alpha: 0.6),
                        height: 1.3,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
