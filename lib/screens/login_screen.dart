import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:penny_pop_app/auth/auth_service.dart';

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
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Google button: keep the standard white style in light mode, use a dark
    // variant in dark mode for contrast.
    final googleButtonBackground = isDark ? const Color(0xFF131314) : Colors.white;
    final googleButtonForeground = isDark ? Colors.white : Colors.black87;
    final googleButtonBorder =
        isDark ? const Color(0xFF8E918F) : const Color(0xFFDADCE0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Finance management for The Lemons.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _continueWithGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: googleButtonBackground,
                        foregroundColor: googleButtonForeground,
                        side: BorderSide(color: googleButtonBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: googleButtonForeground,
                              ),
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
                                const Flexible(
                                  child: Text(
                                    'Continue with Google',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sticking to your budget = reaching your goals.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
