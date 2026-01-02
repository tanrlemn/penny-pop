import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
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
    final household = PennyPopScope.householdOf(context);
    final active = household.active;

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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('My info'),
            subtitle: const Text('User ID + email (copyable)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/me'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Household',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (household.isLoading)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Loading household...'),
              subtitle: LinearProgressIndicator(),
            )
          else if (household.error != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Household failed to load'),
              subtitle: Text('${household.error}'),
              trailing: IconButton(
                onPressed: () => household.refresh(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry',
              ),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Household name'),
              subtitle: Text(active?.name ?? 'Not set'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Household id'),
              subtitle: Text(active?.id ?? 'Not set'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('My role'),
              subtitle: Text(active?.role ?? 'Not set'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Refresh household'),
              subtitle: const Text('Use this after an admin adds you'),
              trailing: const Icon(Icons.refresh),
              onTap: () => household.refresh(),
            ),
            if (active?.role == 'admin')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add partner'),
                subtitle: const Text('Add a member by email'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/add-partner'),
              ),
          ],
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


