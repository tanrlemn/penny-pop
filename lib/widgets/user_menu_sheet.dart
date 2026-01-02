import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:penny_pop_app/households/household_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';

Future<void> showUserMenuSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => _UserDrawerSheet(parentContext: context),
  );
}

enum _UserSheetRoute { menu, account, myInfo, invitePartner }

class _UserDrawerSheet extends StatefulWidget {
  const _UserDrawerSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_UserDrawerSheet> createState() => _UserDrawerSheetState();
}

class _UserDrawerSheetState extends State<_UserDrawerSheet> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  _UserSheetRoute _route = _UserSheetRoute.menu;

  final _emailController = TextEditingController();
  bool _saving = false;
  String? _lastAddedEmail;
  String? _lastAddedUserId;

  String? _pendingRouteName;
  bool _routeUpdateScheduled = false;

  late final NavigatorObserver _navObserver = _SheetNavObserver(
    onChanged: _scheduleRouteUpdate,
  );

  _UserSheetRoute _routeFromName(String? name) {
    return switch (name) {
      'account' => _UserSheetRoute.account,
      'myInfo' => _UserSheetRoute.myInfo,
      'invitePartner' => _UserSheetRoute.invitePartner,
      _ => _UserSheetRoute.menu,
    };
  }

  void _scheduleRouteUpdate(String? name) {
    _pendingRouteName = name;
    if (_routeUpdateScheduled) return;
    _routeUpdateScheduled = true;

    // Navigator observers can fire during the nested Navigator's build/restore.
    // Defer updates to avoid "setState() called during build" exceptions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeUpdateScheduled = false;
      if (!mounted) return;

      final nextRoute = _routeFromName(_pendingRouteName);
      if (_route == nextRoute) return;
      setState(() => _route = nextRoute);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _title {
    return switch (_route) {
      _UserSheetRoute.menu => 'Account',
      _UserSheetRoute.account => 'Account & household',
      _UserSheetRoute.myInfo => 'My info',
      _UserSheetRoute.invitePartner => 'Invite partner',
    };
  }

  bool get _canGoBack => _navKey.currentState?.canPop() ?? false;

  void _goBack() {
    if (_canGoBack) {
      _navKey.currentState?.maybePop();
    }
  }

  void _push(_UserSheetRoute route) {
    final navigator = _navKey.currentState;
    if (navigator == null) return;

    navigator.push(
      _sheetRoute(
        route: route,
        email: AuthService.instance.currentUser?.email ?? 'Not signed in',
      ),
    );
  }

  void _closeSheet() => Navigator.of(context).pop();

  Future<void> _signOutFlow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('You can sign back in anytime.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _closeSheet();
    try {
      await AuthService.instance.signOut(alsoSignOutGoogle: true);
    } catch (e) {
      if (!widget.parentContext.mounted) return;
      ScaffoldMessenger.of(
        widget.parentContext,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? 'Not signed in';

    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        if (_canGoBack) {
          _goBack();
          return;
        }
        _closeSheet();
      },
      child: Builder(
        builder: (context) {
          final viewInsets = MediaQuery.of(context).viewInsets;
          final height = MediaQuery.sizeOf(context).height * 0.7;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SizedBox(
              height: height,
              child: Material(
                child: Column(
                  children: [
                    _SheetHeader(
                      title: _title,
                      canGoBack: _canGoBack,
                      onBack: _goBack,
                    ),
                    Expanded(
                      child: Navigator(
                        key: _navKey,
                        observers: [_navObserver],
                        onGenerateRoute: (settings) {
                          // Initial route.
                          if (settings.name == null || settings.name == '/') {
                            return _sheetRoute(
                              route: _UserSheetRoute.menu,
                              email: email,
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PageRoute<void> _sheetRoute({
    required _UserSheetRoute route,
    required String email,
  }) {
    final name = switch (route) {
      _UserSheetRoute.menu => 'menu',
      _UserSheetRoute.account => 'account',
      _UserSheetRoute.myInfo => 'myInfo',
      _UserSheetRoute.invitePartner => 'invitePartner',
    };

    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (context, animation, secondaryAnimation) {
        final household = PennyPopScope.householdOf(widget.parentContext);
        final active = household.active;
        final isAdmin = active?.role == 'admin';
        final householdName = active?.name ?? 'No household';

        final user = AuthService.instance.currentUser;

        final page = switch (route) {
          _UserSheetRoute.menu => _MenuPage(
            key: const ValueKey('menu'),
            email: email,
            householdName: householdName,
            isAdmin: isAdmin,
            onAccount: () => _push(_UserSheetRoute.account),
            onMyInfo: () => _push(_UserSheetRoute.myInfo),
            onInvitePartner: isAdmin
                ? () => _push(_UserSheetRoute.invitePartner)
                : null,
            onSignOut: _signOutFlow,
          ),
          _UserSheetRoute.account => _AccountPage(
            key: const ValueKey('account'),
            email: email,
            household: household,
          ),
          _UserSheetRoute.myInfo => _MyInfoPage(
            key: const ValueKey('myInfo'),
            userId: user?.id,
            email: user?.email,
            parentContext: widget.parentContext,
          ),
          _UserSheetRoute.invitePartner => _InvitePartnerPage(
            key: const ValueKey('invitePartner'),
            parentContext: widget.parentContext,
            householdId: active?.id,
            householdName: active?.name,
            isAdmin: isAdmin,
            emailController: _emailController,
            saving: _saving,
            lastAddedEmail: _lastAddedEmail,
            lastAddedUserId: _lastAddedUserId,
            onChanged: () => setState(() {}),
            onSubmit: (householdId, email) async {
              if (_saving) return;
              setState(() => _saving = true);
              try {
                final userId = await HouseholdService()
                    .addHouseholdMemberByEmail(
                      householdId: householdId,
                      email: email,
                    );
                if (!mounted) return;
                FocusScope.of(context).unfocus();
                _emailController.clear();
                setState(() {
                  _lastAddedEmail = email;
                  _lastAddedUserId = userId;
                });
                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                  SnackBar(content: Text('Partner added: $email')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                  SnackBar(content: Text('Add partner failed: $e')),
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        };

        // Ensure the new route paints a solid background immediately (prevents
        // seeing the previous page under a fade).
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: page,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}

class _SheetNavObserver extends NavigatorObserver {
  _SheetNavObserver({required this.onChanged});

  final void Function(String? name) onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged(previousRoute?.settings.name);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.canGoBack,
    required this.onBack,
  });

  final String title;
  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const PixelIcon(
                'assets/icons/ui/back.svg',
                semanticLabel: 'Back',
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({
    super.key,
    required this.email,
    required this.householdName,
    required this.isAdmin,
    required this.onAccount,
    required this.onMyInfo,
    required this.onInvitePartner,
    required this.onSignOut,
  });

  final String email;
  final String householdName;
  final bool isAdmin;
  final VoidCallback onAccount;
  final VoidCallback onMyInfo;
  final VoidCallback? onInvitePartner;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: IconTheme(
              data: IconThemeData(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const PixelIcon(
                'assets/icons/ui/account.svg',
                semanticLabel: 'Account',
                size: 20,
              ),
            ),
          ),
          title: Text(email),
          subtitle: Text(householdName),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const PixelIcon(
            'assets/icons/ui/settings.svg',
            semanticLabel: 'Account & household',
          ),
          title: const Text('Account & household'),
          trailing: const PixelIcon(
            'assets/icons/ui/chevron_right.svg',
            semanticLabel: 'Open',
            size: 20,
          ),
          onTap: onAccount,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const PixelIcon(
            'assets/icons/ui/badge.svg',
            semanticLabel: 'My info',
          ),
          title: const Text('My info'),
          trailing: const PixelIcon(
            'assets/icons/ui/chevron_right.svg',
            semanticLabel: 'Open',
            size: 20,
          ),
          onTap: onMyInfo,
        ),
        if (isAdmin)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const PixelIcon(
              'assets/icons/ui/person_add.svg',
              semanticLabel: 'Invite partner',
            ),
            title: const Text('Invite partner'),
            trailing: const PixelIcon(
              'assets/icons/ui/chevron_right.svg',
              semanticLabel: 'Open',
              size: 20,
            ),
            onTap: onInvitePartner,
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const PixelIcon(
            'assets/icons/ui/logout.svg',
            semanticLabel: 'Sign out',
          ),
          title: const Text('Sign out'),
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({super.key, required this.email, required this.household});

  final String email;
  final ActiveHouseholdController household;

  @override
  Widget build(BuildContext context) {
    final active = household.active;

    return ListView(
      key: key,
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
          subtitle: Text(email),
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
            subtitle: const Text('Tap to retry'),
            trailing: const PixelIcon(
              'assets/icons/ui/refresh.svg',
              semanticLabel: 'Retry',
              size: 20,
            ),
            onTap: () => household.refresh(),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Current household'),
            subtitle: Text(active?.name ?? 'Not set'),
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Troubleshooting'),
          subtitle: const Text('Only needed for support / setup issues'),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync membership'),
              subtitle: const Text('Use if you were just added to a household'),
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
    );
  }
}

class _MyInfoPage extends StatelessWidget {
  const _MyInfoPage({
    super.key,
    required this.userId,
    required this.email,
    required this.parentContext,
  });

  final String? userId;
  final String? email;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    Future<void> copy(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(SnackBar(content: Text('$label copied')));
    }

    final displayUserId = userId ?? 'Not signed in';
    final displayEmail = email ?? 'Not signed in';

    return ListView(
      key: key,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Share these with your partner/admin if needed.',
          style: TextStyle(height: 1.3),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('User ID'),
          subtitle: Text(displayUserId),
          trailing: IconButton(
            onPressed: userId == null
                ? null
                : () => copy(displayUserId, 'User ID'),
            icon: const PixelIcon(
              'assets/icons/ui/copy.svg',
              semanticLabel: 'Copy',
            ),
            tooltip: 'Copy',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email'),
          subtitle: Text(displayEmail),
          trailing: IconButton(
            onPressed: email == null ? null : () => copy(displayEmail, 'Email'),
            icon: const PixelIcon(
              'assets/icons/ui/copy.svg',
              semanticLabel: 'Copy',
            ),
            tooltip: 'Copy',
          ),
        ),
      ],
    );
  }
}

class _InvitePartnerPage extends StatelessWidget {
  const _InvitePartnerPage({
    super.key,
    required this.parentContext,
    required this.householdId,
    required this.householdName,
    required this.isAdmin,
    required this.emailController,
    required this.saving,
    required this.lastAddedEmail,
    required this.lastAddedUserId,
    required this.onChanged,
    required this.onSubmit,
  });

  final BuildContext parentContext;
  final String? householdId;
  final String? householdName;
  final bool isAdmin;

  final TextEditingController emailController;
  final bool saving;
  final String? lastAddedEmail;
  final String? lastAddedUserId;

  final VoidCallback onChanged;
  final Future<void> Function(String householdId, String email) onSubmit;

  @override
  Widget build(BuildContext context) {
    final emailText = emailController.text.trim();
    final canSubmit =
        isAdmin && householdId != null && !saving && emailText.isNotEmpty;

    return ListView(
      key: key,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your partner must sign in once first, then enter their email here.',
          style: TextStyle(height: 1.3),
        ),
        if (lastAddedEmail != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: PixelIcon(
                    'assets/icons/ui/check_circle.svg',
                    semanticLabel: 'Success',
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lastAddedUserId == null
                        ? 'Added $lastAddedEmail. They may need to open Account & household → Troubleshooting → Sync membership (or restart the app) to see the shared household.'
                        : 'Added $lastAddedEmail (user: $lastAddedUserId). They may need to open Account & household → Troubleshooting → Sync membership (or restart the app) to see the shared household.',
                    style: const TextStyle(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (householdId == null)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Household not loaded yet'),
            subtitle: Text('Go back and try again in a moment.'),
          )
        else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Household'),
            subtitle: Text('${householdName ?? ''}\n$householdId'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Partner email',
              hintText: 'partner@gmail.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !canSubmit
                ? null
                : () => onSubmit(householdId!, emailText),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Invite partner'),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'Only admins can add members.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
