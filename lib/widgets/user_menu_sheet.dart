import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/auth/auth_service.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/households/household_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';

Future<void> showUserMenuSheet(BuildContext context) async {
  await showCupertinoModalPopup<void>(
    context: context,
    useRootNavigator: true,
    builder: (popupContext) => _UserMenuSheet(parentContext: context),
  );
}

enum _UserSheetPage { menu, account, myInfo, invitePartner }

class _UserMenuSheet extends StatefulWidget {
  const _UserMenuSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_UserMenuSheet> createState() => _UserMenuSheetState();
}

class _UserMenuSheetState extends State<_UserMenuSheet> {
  _UserSheetPage _page = _UserSheetPage.menu;

  final TextEditingController _inviteEmailController = TextEditingController();
  bool _savingInvite = false;
  String? _lastAddedEmail;
  String? _lastAddedUserId;

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  bool get _canGoBack => _page != _UserSheetPage.menu;

  void _goBack() => setState(() => _page = _UserSheetPage.menu);

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  String get _title => switch (_page) {
        _UserSheetPage.menu => 'Account',
        _UserSheetPage.account => 'Account & household',
        _UserSheetPage.myInfo => 'My info',
        _UserSheetPage.invitePartner => 'Invite partner',
      };

  Future<void> _signOutFlow() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Sign out?'),
          content: const Text('You can sign back in anytime.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed != true) return;

    _close(); // close sheet
    try {
      await AuthService.instance.signOut(alsoSignOutGoogle: true);
    } catch (e) {
      if (!widget.parentContext.mounted) return;
      showGlassToast(widget.parentContext, 'Sign out failed: $e');
    }
  }

  Future<void> _invitePartner({
    required String householdId,
    required String email,
  }) async {
    if (_savingInvite) return;
    setState(() => _savingInvite = true);
    try {
      final userId = await HouseholdService().addHouseholdMemberByEmail(
        householdId: householdId,
        email: email,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _inviteEmailController.clear();
      setState(() {
        _lastAddedEmail = email;
        _lastAddedUserId = userId;
      });
      showGlassToast(context, 'Partner added: $email');
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Add partner failed: $e');
    } finally {
      if (mounted) setState(() => _savingInvite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? 'Not signed in';

    final household = PennyPopScope.householdOf(widget.parentContext);
    final active = household.active;
    final isAdmin = active?.role == 'admin';
    final householdName = active?.name ?? 'No household';

    final height = MediaQuery.sizeOf(context).height * 0.62;
    final reduceMotion = GlassAdaptive.reduceMotionOf(context);

    final content = switch (_page) {
      _UserSheetPage.menu => _MenuPage(
          email: email,
          householdName: householdName,
          isAdmin: isAdmin,
          onAccount: () => setState(() => _page = _UserSheetPage.account),
          onMyInfo: () => setState(() => _page = _UserSheetPage.myInfo),
          onInvitePartner: isAdmin
              ? () => setState(() => _page = _UserSheetPage.invitePartner)
              : null,
          onSignOut: _signOutFlow,
        ),
      _UserSheetPage.account => _AccountPage(householdName: householdName),
      _UserSheetPage.myInfo => _MyInfoPage(
          userId: user?.id,
          email: user?.email,
        ),
      _UserSheetPage.invitePartner => _InvitePartnerPage(
          isAdmin: isAdmin,
          householdId: active?.id,
          householdName: active?.name,
          emailController: _inviteEmailController,
          saving: _savingInvite,
          lastAddedEmail: _lastAddedEmail,
          lastAddedUserId: _lastAddedUserId,
          onChanged: () => setState(() {}),
          onSubmit: _invitePartner,
        ),
    };

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_canGoBack) _goBack();
      },
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              padding: EdgeInsets.zero,
            child: SizedBox(
              height: height,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey2.resolveFrom(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (_canGoBack)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _goBack,
                              child: const Icon(CupertinoIcons.back, size: 18),
                            )
                          else
                            const SizedBox(width: 34),
                          Expanded(
                            child: Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .navTitleTextStyle,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _close,
                            child: const Icon(CupertinoIcons.xmark, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) {
                          if (reduceMotion) return child;
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: KeyedSubtree(
                          key: ValueKey<_UserSheetPage>(_page),
                          child: content,
                        ),
                      ),
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

class _AccountHeaderRow extends StatelessWidget {
  const _AccountHeaderRow({
    required this.email,
    required this.householdName,
  });

  final String email;
  final String householdName;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    // Pattern 1: iOS-style profile header (non-interactive).
    // - icon/avatar + primary line + secondary line
    // - no labels, no chevron, no button highlight
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: PixelIcon(
                  'assets/icons/ui/account.svg',
                  semanticLabel: 'Account',
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          color: primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    householdName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          color: secondary,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
            SizedBox(width: 24, height: 24, child: Center(child: leading)),
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .copyWith(color: titleColor, fontSize: 16),
              ),
            ),
            trailing ??
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage({
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _AccountHeaderRow(email: email, householdName: householdName),
        const SizedBox(height: 10),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
            'assets/icons/ui/settings.svg',
            semanticLabel: 'Account & household',
          ),
          title: 'Account & household',
          onTap: onAccount,
        ),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
            'assets/icons/ui/badge.svg',
            semanticLabel: 'My info',
          ),
          title: 'My info',
          onTap: onMyInfo,
        ),
        if (isAdmin) ...[
          const _SheetDivider(),
          _SheetRow(
            leading: const PixelIcon(
              'assets/icons/ui/person_add.svg',
              semanticLabel: 'Invite partner',
            ),
            title: 'Invite partner',
            onTap: onInvitePartner,
          ),
        ],
        const SizedBox(height: 10),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
            'assets/icons/ui/logout.svg',
            semanticLabel: 'Sign out',
          ),
          title: 'Sign out',
          isDestructive: true,
          trailing: const SizedBox.shrink(),
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.householdName});

  final String householdName;

  @override
  Widget build(BuildContext context) {
    final household = PennyPopScope.householdOf(context);
    final active = household.active;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _AccountHeaderRow(
          email: AuthService.instance.currentUser?.email ?? 'Not signed in',
          householdName: householdName,
        ),
        const SizedBox(height: 10),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
            'assets/icons/ui/sync.svg',
            semanticLabel: 'Sync',
          ),
          title: 'Sync membership',
          onTap: household.refresh,
          trailing: household.isLoading
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.chevron_right, size: 18),
        ),
        if (active != null) ...[
          const _SheetDivider(),
          _SheetRow(
            leading: const PixelIcon(
              'assets/icons/ui/badge.svg',
              semanticLabel: 'Role',
            ),
            title: 'Role: ${active.role}',
            onTap: null,
            trailing: const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _MyInfoPage extends StatelessWidget {
  const _MyInfoPage({required this.userId, required this.email});

  final String? userId;
  final String? email;

  @override
  Widget build(BuildContext context) {
    Future<void> copy(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      showGlassToast(context, '$label copied');
    }

    final displayUserId = userId ?? 'Not signed in';
    final displayEmail = email ?? 'Not signed in';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const Text('Share these with your partner/admin if needed.'),
        const SizedBox(height: 10),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
              'assets/icons/ui/copy.svg',
              semanticLabel: 'Copy',
          ),
          title: 'Copy user ID',
          onTap: userId == null ? null : () => copy(displayUserId, 'User ID'),
        ),
        const _SheetDivider(),
        _SheetRow(
          leading: const PixelIcon(
              'assets/icons/ui/copy.svg',
              semanticLabel: 'Copy',
          ),
          title: 'Copy email',
          onTap: email == null ? null : () => copy(displayEmail, 'Email'),
        ),
      ],
    );
  }
}

class _InvitePartnerPage extends StatelessWidget {
  const _InvitePartnerPage({
    required this.isAdmin,
    required this.householdId,
    required this.householdName,
    required this.emailController,
    required this.saving,
    required this.lastAddedEmail,
    required this.lastAddedUserId,
    required this.onChanged,
    required this.onSubmit,
  });

  final bool isAdmin;
  final String? householdId;
  final String? householdName;

  final TextEditingController emailController;
  final bool saving;
  final String? lastAddedEmail;
  final String? lastAddedUserId;

  final VoidCallback onChanged;
  final Future<void> Function({required String householdId, required String email})
      onSubmit;

  @override
  Widget build(BuildContext context) {
    final emailText = emailController.text.trim();
    final canSubmit =
        isAdmin && householdId != null && !saving && emailText.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const Text(
          'Your partner must sign in once first, then enter their email here.',
          style: TextStyle(height: 1.3),
        ),
        if (lastAddedEmail != null) ...[
          const SizedBox(height: 10),
          Text(
                    lastAddedUserId == null
                ? 'Added $lastAddedEmail.'
                : 'Added $lastAddedEmail (user: $lastAddedUserId).',
          ),
        ],
        const SizedBox(height: 10),
        Text(
          householdId == null
              ? 'Household not loaded yet.'
              : 'Household: ${householdName ?? ''}',
        ),
        const SizedBox(height: 10),
        CupertinoTextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => onChanged(),
          placeholder: 'partner@gmail.com',
          ),
          const SizedBox(height: 12),
        CupertinoButton.filled(
            onPressed: !canSubmit
                ? null
              : () => onSubmit(householdId: householdId!, email: emailText),
            child: saving
              ? const CupertinoActivityIndicator()
                : const Text('Invite partner'),
          ),
      ],
    );
  }
}


