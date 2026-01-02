import 'dart:async';

import 'package:flutter/material.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final StreamSubscription<AuthState> _sub;
  User? _user;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() => _user = AuthService.instance.currentUser);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await AuthService.instance.signOut(alsoSignOutGoogle: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email'),
            subtitle: Text(email ?? 'Not signed in'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: email == null || _signingOut ? null : _signOut,
            child: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}


