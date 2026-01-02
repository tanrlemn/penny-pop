import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
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
      showGlassToast(context, 'Sign out failed: $e');
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

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: household.refresh),
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: const Text('Account'),
              children: <Widget>[
                CupertinoListTile(
                  title: const Text('Email'),
                  additionalInfo: Text(email ?? 'Not signed in'),
                ),
                CupertinoListTile(
                  title: const Text('Sign out'),
                  leading: const PixelIcon(
                    'assets/icons/ui/logout.svg',
                    semanticLabel: 'Sign out',
                  ),
                  trailing: _signingOut
                      ? const CupertinoActivityIndicator()
                      : const Icon(CupertinoIcons.chevron_right, size: 18),
                  onTap: email == null || _signingOut ? null : _signOut,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: const Text('Household'),
              children: <Widget>[
                if (household.isLoading)
                  const CupertinoListTile(
                    title: Text('Loading household...'),
                    trailing: CupertinoActivityIndicator(),
                  )
                else if (household.error != null)
                  CupertinoListTile(
                    title: const Text('Household couldn’t load'),
                    additionalInfo: const Text('Tap to retry'),
                    trailing: const PixelIcon(
                      'assets/icons/ui/refresh.svg',
                      semanticLabel: 'Retry',
                      size: 20,
                    ),
                    onTap: () => household.refresh(),
                  )
                else
                  CupertinoListTile(
                    title: const Text('Current household'),
                    additionalInfo: Text(active?.name ?? 'Not set'),
                  ),
                if (isAdmin)
                  CupertinoListTile(
                    title: const Text('Invite partner'),
                    additionalInfo: const Text('Add a member by email'),
                    trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                    onTap: () => context.push('/settings/add-partner'),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: const Text('Troubleshooting'),
              footer: const Text('Only needed for support / setup issues.'),
              children: <Widget>[
                CupertinoListTile(
                  title: const Text('My info'),
                  additionalInfo: const Text('User ID + email (copyable)'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                  onTap: () => context.push('/settings/me'),
                ),
                CupertinoListTile(
                  title: const Text('Sync membership'),
                  additionalInfo: const Text('Use if you were just added'),
                  trailing: const PixelIcon(
                    'assets/icons/ui/sync.svg',
                    semanticLabel: 'Sync',
                    size: 20,
                  ),
                  onTap: household.refresh,
                ),
                if (active != null) ...<Widget>[
                  CupertinoListTile(
                    title: const Text('Household ID'),
                    additionalInfo: Text(active.id),
                  ),
                  CupertinoListTile(
                    title: const Text('Permissions'),
                    additionalInfo: Text(active.role == 'admin' ? 'Admin' : 'Member'),
                  ),
                ],
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
