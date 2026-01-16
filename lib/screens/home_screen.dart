import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/overview/budget_snapshot.dart';
import 'package:penny_pop_app/overview/budget_snapshot_service.dart';
import 'package:penny_pop_app/overview/route_extras.dart';
import 'package:penny_pop_app/pods/pods_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BudgetSnapshotService _snapshotService = BudgetSnapshotService();
  final PodsService _podsService = PodsService();

  bool _loading = false;
  Object? _error;
  BudgetSnapshot? _snapshot;

  String? _lastHouseholdId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId != null && householdId != _lastHouseholdId) {
      _lastHouseholdId = householdId;
      _load();
    }
  }

  Future<void> _load() async {
    final householdId = PennyPopScope.householdOf(context).active?.id;
    if (householdId == null) return;
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _snapshotService.load(householdId: householdId);
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _withCommas(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      final nextFromEnd = idxFromEnd - 1;
      if (nextFromEnd > 0 && nextFromEnd % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  String _formatCents(int? cents) {
    if (cents == null) return '—';
    final neg = cents < 0;
    var v = cents.abs();
    final dollars = v ~/ 100;
    final rem = v % 100;
    final dollarsStr = _withCommas(dollars);
    return '${neg ? '-' : ''}\$$dollarsStr.${rem.toString().padLeft(2, '0')}';
  }

  Future<void> _syncBalances() async {
    final household = PennyPopScope.householdOf(context).active;
    final isAdmin = household?.role == 'admin';
    if (!isAdmin) {
      showGlassToast(context, 'Ask an admin to sync balances.');
      return;
    }
    try {
      showGlassToast(context, 'Syncing balances…');
      await _podsService.syncPodsFromSequence();
      if (!mounted) return;
      showGlassToast(context, 'Synced.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showGlassToast(context, 'Sync failed.');
    }
  }

  List<_AttentionCardModel> _buildAttention(BudgetSnapshot snap) {
    final items = <_AttentionCardModel>[];

    final left = snap.leftToBudgetCents;
    if (left > 0) {
      items.add(
        _AttentionCardModel(
          id: 'unassigned',
          title: '${_formatCents(left)} unassigned',
          subtitle: 'Assign leftover money to envelopes.',
          onTap: () => context.go(
            '/chat',
            extra: ChatScreenArgs(
              initialPrompt:
                  'I have ${_formatCents(left)} unassigned income. Help me allocate it.',
            ),
          ),
        ),
      );
    } else if (left < 0) {
      items.add(
        _AttentionCardModel(
          id: 'over_budget',
          title: '${_formatCents(left.abs())} over budget',
          subtitle: 'Review budgets to get back to zero.',
          onTap: () => context.go('/pods'),
        ),
      );
    }

    if (snap.missingBudgetCount > 0) {
      items.add(
        _AttentionCardModel(
          id: 'missing_budget',
          title: 'Set budgets for ${snap.missingBudgetCount} envelopes',
          subtitle: 'Some envelopes have no budget set yet.',
          onTap: () => context.go(
            '/pods',
            extra: const PodsScreenArgs(
              focusTarget: PodsFocusTarget(filter: PodsFocusFilter.missingBudget),
            ),
          ),
        ),
      );
    }

    if (snap.uncategorizedCount > 0) {
      items.add(
        _AttentionCardModel(
          id: 'uncategorized',
          title: 'Categorize ${snap.uncategorizedCount} envelopes',
          subtitle: 'Some envelopes aren’t assigned to a section.',
          onTap: () => context.go(
            '/pods',
            extra: const PodsScreenArgs(
              focusTarget: PodsFocusTarget(filter: PodsFocusFilter.uncategorized),
            ),
          ),
        ),
      );
    }

    final latest = snap.latestBalanceUpdatedAt;
    if (latest != null) {
      final age = DateTime.now().toUtc().difference(latest.toUtc());
      const staleAfter = Duration(minutes: 30);
      if (age > staleAfter) {
        items.add(
          _AttentionCardModel(
            id: 'balances_stale',
            title: 'Balances may be stale',
            subtitle: 'Pull to refresh in Envelopes or tap to sync.',
            onTap: _syncBalances,
          ),
        );
      }
    }

    if (items.length > 5) return items.sublist(0, 5);
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = CupertinoColors.label.resolveFrom(context);
    final secondaryText = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dividerColor = CupertinoColors.separator.resolveFrom(context);

    final snap = _snapshot;
    final attention = snap == null ? const <_AttentionCardModel>[] : _buildAttention(snap);

    final healthStatus = snap?.healthStatus;
    final statusIcon = switch (healthStatus) {
      BudgetHealthStatus.onTrack => CupertinoIcons.check_mark_circled_solid,
      BudgetHealthStatus.needsAssigning => CupertinoIcons.exclamationmark_circle_fill,
      BudgetHealthStatus.overBudget => CupertinoIcons.xmark_circle_fill,
      null => CupertinoIcons.circle,
    };
    final statusColor = switch (healthStatus) {
      BudgetHealthStatus.onTrack => CupertinoColors.systemGreen.resolveFrom(context),
      BudgetHealthStatus.needsAssigning => CupertinoColors.systemOrange.resolveFrom(context),
      BudgetHealthStatus.overBudget => CupertinoColors.systemRed.resolveFrom(context),
      null => secondaryText,
    };

    final healthTitle = switch (healthStatus) {
      BudgetHealthStatus.onTrack => 'You’re on track',
      BudgetHealthStatus.needsAssigning => 'You have money left',
      BudgetHealthStatus.overBudget => 'You’re over budget',
      null => 'Budget health',
    };
    final primaryNumber = (snap == null)
        ? '—'
        : snap.leftToBudgetCents == 0
            ? '\$0.00'
            : _formatCents(snap.leftToBudgetCents.abs());
    final primaryLabel = (snap == null)
        ? ''
        : snap.leftToBudgetCents < 0
            ? 'Over by'
            : snap.leftToBudgetCents > 0
                ? 'Unassigned'
                : 'Left to budget';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Overview'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showUserMenuSheet(context),
          child: const PixelIcon(
            'assets/icons/ui/account.svg',
            semanticLabel: 'Account',
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _load),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  healthTitle,
                                  style: TextStyle(
                                    color: primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            primaryLabel,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            primaryNumber,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (snap != null) ...[
                            const SizedBox(height: 10),
                            Container(height: 1, color: dividerColor),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryMini(
                                    label: 'Income',
                                    value: _formatCents(snap.totalIncomeCents),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _summaryMini(
                                    label: 'Budgeted',
                                    value: _formatCents(snap.totalExpenseCents),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Needs attention',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    else if (_error != null)
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Overview couldn’t load.\n$_error',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (snap == null || attention.isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Text(
                          'All set.',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      ...attention.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _attentionCard(
                            item,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMini({
    required String label,
    required String value,
    required Color secondaryText,
    required Color primaryText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _attentionCard(
    _AttentionCardModel item, {
    required Color primaryText,
    required Color secondaryText,
  }) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        onPressed: item.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionCardModel {
  const _AttentionCardModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}
