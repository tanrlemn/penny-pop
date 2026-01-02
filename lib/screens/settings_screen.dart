import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email;
    final household = PennyPopScope.householdOf(context);
    final active = household.active;
    final isAdmin = active?.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: household.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
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
                title: const Text('Household couldn’t load'),
                subtitle: const Text('Pull down to retry'),
                trailing: IconButton(
                  onPressed: () => household.refresh(),
                  icon: const PixelIcon(
                    'assets/icons/ui/refresh.svg',
                    semanticLabel: 'Retry',
                  ),
                  tooltip: 'Retry',
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Current household'),
                subtitle: Text(active?.name ?? 'Not set'),
              ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invite partner'),
                subtitle: const Text('Add a member by email'),
                  trailing: const PixelIcon(
                    'assets/icons/ui/chevron_right.svg',
                    semanticLabel: 'Open',
                    size: 20,
                  ),
                onTap: () => context.push('/settings/add-partner'),
              ),
            ],
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Troubleshooting'),
              subtitle: const Text('Only needed for support / setup issues'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('My info'),
                  subtitle: const Text('User ID + email (copyable)'),
                  trailing: const PixelIcon(
                    'assets/icons/ui/chevron_right.svg',
                    semanticLabel: 'Open',
                    size: 20,
                  ),
                  onTap: () => context.push('/settings/me'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sync membership'),
                  subtitle: const Text(
                    'Use if you were just added to a household',
                  ),
                  trailing: const PixelIcon(
                    'assets/icons/ui/sync.svg',
                    semanticLabel: 'Sync',
                    size: 20,
                  ),
                  onTap: () => household.refresh(),
                ),
                if (active != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Household ID'),
                    subtitle: Text(active.id),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permissions'),
                    subtitle: Text(active.role == 'admin' ? 'Admin' : 'Member'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
