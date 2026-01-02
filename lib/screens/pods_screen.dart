import 'package:flutter/cupertino.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
import 'package:penny_pop_app/income/income_models.dart';
import 'package:penny_pop_app/income/income_service.dart';
import 'package:penny_pop_app/pods/pod_models.dart';
import 'package:penny_pop_app/pods/pods_service.dart';
import 'package:penny_pop_app/widgets/pixel_icon.dart';
import 'package:penny_pop_app/widgets/user_menu_sheet.dart';

class PodsScreen extends StatefulWidget {
  const PodsScreen({super.key});

  @override
  State<PodsScreen> createState() => _PodsScreenState();
}

class _PodsScreenState extends State<PodsScreen> {
  final PodsService _service = PodsService();
  final IncomeSourcesService _incomeService = IncomeSourcesService();

  bool _loading = false;
  bool _syncing = false;
  Object? _error;
  List<Pod> _pods = const [];
  List<IncomeSource> _incomeSources = const [];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();

  String _activeStickySection = 'Income';

  // In-list section markers used to compute the active section for the single
  // sticky header (so headers “replace” instead of stacking).
  final Map<String, GlobalKey> _sectionMarkerKeys = <String, GlobalKey>{
    'Income': GlobalKey(),
    'Savings': GlobalKey(),
    'Kiddos': GlobalKey(),
    'Necessities': GlobalKey(),
    'Pressing': GlobalKey(),
    'Discretionary': GlobalKey(),
    'Uncategorized': GlobalKey(),
  };

  String? _lastHouseholdId;
  DateTime? _lastAutoSyncAttemptAt;
  String? _lastAutoSyncHouseholdId;

  static const _expenseSections = <String>[
    'Savings',
    'Kiddos',
    'Necessities',
    'Pressing',
    'Discretionary',
  ];

  static const _sectionOptions = <String>[
    'Income',
    ..._expenseSections,
  ];

  String _formatCents(int? cents) {
    if (cents == null) return '—';
    final neg = cents < 0;
    var v = cents.abs();
    final dollars = v ~/ 100;
    final rem = v % 100;
    final dollarsStr = _withCommas(dollars);
    return '${neg ? '-' : ''}\$$dollarsStr.${rem.toString().padLeft(2, '0')}';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrollBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null || !scrollBox.attached) return;

    final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
    final threshold = viewportTop +
        _BudgetSignalHeaderDelegate.height +
        _StickyHeaderDelegate.height +
        1;

    String? bestTitle;
    double bestY = double.negativeInfinity;

    for (final entry in _sectionMarkerKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= threshold && y > bestY) {
        bestY = y;
        bestTitle = entry.key;
      }
    }

    final next = bestTitle ?? _activeStickySection;
    if (next != _activeStickySection) {
      setState(() => _activeStickySection = next);
    }
  }

  Color _sectionColor(String title) {
    switch (title) {
      case 'Income':
        return CupertinoColors.systemTeal.resolveFrom(context);
      case 'Necessities':
        return CupertinoColors.systemYellow.resolveFrom(context);
      case 'Pressing':
        return CupertinoColors.systemOrange.resolveFrom(context);
      case 'Savings':
        return CupertinoColors.systemPurple.resolveFrom(context);
      case 'Discretionary':
        return CupertinoColors.systemBlue.resolveFrom(context);
      case 'Kiddos':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.systemGrey.resolveFrom(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final household = PennyPopScope.householdOf(context).active;
    final householdId = household?.id;
    if (householdId != null && householdId != _lastHouseholdId) {
      _lastHouseholdId = householdId;
      _load();
      _maybeAutoSync();
    }
  }

  Future<void> _load() async {
    final active = PennyPopScope.householdOf(context).active;
    final householdId = active?.id;
    if (householdId == null) return;

    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pods = await _service.listPods(householdId: householdId);
      List<IncomeSource> sources = const [];
      try {
        sources = await _incomeService.listIncomeSources(householdId: householdId);
      } catch (_) {
        // Tolerate missing table / migrations during local dev.
        sources = const [];
      }
      if (!mounted) return;
      setState(() {
        _pods = pods;
        _incomeSources = sources;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFromSequence({bool showFeedback = true}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final data = await _service.syncPodsFromSequence();
      if (!mounted) return;
      if (data != null && showFeedback) {
        final upserted = data['upserted'] ?? 0;
        final deactivated = data['deactivated'] ?? 0;
        final accountsCount = data['accountsCount'];
        final seenPods = data['seenPods'];

        if (upserted == 0 && (seenPods == 0 || seenPods == null)) {
          showGlassToast(
            context,
            'Sync ran, but no Pods were detected from Sequence (accounts: ${accountsCount ?? '?'})',
          );
        } else {
          showGlassToast(
            context,
            'Synced: upserted $upserted, deactivated $deactivated.',
          );
        }
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      if (showFeedback) {
        showGlassToast(context, 'Sync failed: $e');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _maybeAutoSync() async {
    final household = PennyPopScope.householdOf(context).active;
    final householdId = household?.id;
    final isAdmin = household?.role == 'admin';
    if (!isAdmin || householdId == null) return;

    // Throttle auto-sync attempts so we don't hammer Sequence while navigating.
    final now = DateTime.now().toUtc();
    if (_lastAutoSyncHouseholdId == householdId &&
        _lastAutoSyncAttemptAt != null &&
        now.difference(_lastAutoSyncAttemptAt!) < const Duration(minutes: 2)) {
      return;
    }
    _lastAutoSyncHouseholdId = householdId;
    _lastAutoSyncAttemptAt = now;

    try {
      final last = await _service.latestBalanceUpdatedAt(
        householdId: householdId,
      );
      final stale =
          last == null ||
          now.difference(last.toUtc()) > const Duration(minutes: 15);
      if (!stale) return;
      await _syncFromSequence(showFeedback: false);
    } catch (_) {
      // Silent: auto-refresh is best-effort. Manual Sync will still surface errors.
    }
  }

  Future<void> _onPullToRefresh() async {
    final household = PennyPopScope.householdOf(context).active;
    final isAdmin = household?.role == 'admin';
    if (isAdmin) {
      // Force refresh on pull, regardless of staleness.
      await _syncFromSequence(showFeedback: false);
    } else {
      await _load();
    }
  }

  Future<void> _editPodBudget(Pod pod) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) {
        return _PodBudgetSheet(
          pod: pod,
          sectionOptions: _sectionOptions,
          onSave: ({
            required String? category,
            required int? budgetedAmountCents,
          }) async {
            await _service.upsertPodBudget(
              podId: pod.id,
              category: category,
              budgetedAmountCents: budgetedAmountCents,
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == true) {
      showGlassToast(context, 'Saved.');
      await _load();
    }
  }

  Future<void> _editIncomeSource(IncomeSource? source) async {
    final household = PennyPopScope.householdOf(context).active;
    final householdId = household?.id;
    if (householdId == null) return;

    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) {
        return _IncomeSourceSheet(
          source: source,
          onSave: ({
            required String name,
            required int budgetedAmountCents,
          }) async {
            await _incomeService.upsertIncomeSource(
              id: source?.id,
              householdId: householdId,
              name: name,
              budgetedAmountCents: budgetedAmountCents,
              sortOrder: source?.sortOrder,
              isActive: true,
            );
          },
          onArchive: source == null
              ? null
              : () async {
                  await _incomeService.archiveIncomeSource(id: source.id);
                },
        );
      },
    );

    if (!mounted) return;
    if (result == true) {
      showGlassToast(context, 'Saved.');
      await _load();
    }
  }

  bool _isIncome(Pod p) => p.settings?.category == 'Income';

  int _budgetedCents(Pod p) => p.settings?.budgetedAmountCents ?? 0;

  int _sumBudgeted(Iterable<Pod> pods) =>
      pods.fold<int>(0, (sum, p) => sum + _budgetedCents(p));

  int _sumIncomeSourceBudgeted(Iterable<IncomeSource> sources) =>
      sources.fold<int>(0, (sum, s) => sum + s.budgetedAmountCents);

  int? _sumBalances(Iterable<Pod> pods) {
    var sum = 0;
    var any = false;
    for (final p in pods) {
      final bc = p.balanceError == null ? p.balanceCents : null;
      if (bc == null) continue;
      sum += bc;
      any = true;
    }
    return any ? sum : null;
  }

  double? _pctOfIncome({required int partCents, required int incomeCents}) {
    if (incomeCents <= 0) return null;
    return partCents / incomeCents;
  }

  String _formatPct(double? pct) {
    if (pct == null) return '—';
    final v = (pct * 100);
    if (v.isNaN || v.isInfinite) return '—';
    final s = v.toStringAsFixed(v >= 10 ? 0 : 1);
    return '$s%';
  }

  @override
  Widget build(BuildContext context) {
    final householdController = PennyPopScope.householdOf(context);
    final active = householdController.active;
    final isAdmin = active?.role == 'admin';
    final primaryText = CupertinoColors.label.resolveFrom(context);
    final secondaryText = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dividerColor = CupertinoColors.separator.resolveFrom(context);
    final systemRed = CupertinoColors.systemRed.resolveFrom(context);
    final systemGreen = CupertinoColors.systemGreen.resolveFrom(context);

    final incomePods = _pods.where(_isIncome).toList(growable: false);
    final expensePods = _pods.where((p) => !_isIncome(p)).toList(growable: false);

    final totalIncomeCents = _incomeSources.isNotEmpty
        ? _sumIncomeSourceBudgeted(_incomeSources)
        : _sumBudgeted(incomePods);
    final totalExpenseCents = _sumBudgeted(expensePods);
    final leftToBudgetCents = totalIncomeCents - totalExpenseCents;
    final leftPct = _pctOfIncome(
      partCents: leftToBudgetCents,
      incomeCents: totalIncomeCents,
    );
    final incomePodBalanceCents = _sumBalances(incomePods);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Envelopes'),
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
          key: _scrollViewKey,
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _onPullToRefresh),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  isAdmin
                      ? 'Pull to refresh balances'
                      : 'Ask an admin to sync envelopes from Sequence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
              ),
            ),
            if (active == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('Loading household...'),
                ),
              )
            else if (_loading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Envelopes couldn’t load.\n$_error'),
                ),
              )
            else if (_pods.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No envelopes yet.',
                  ),
                ),
              )
            else
              ..._buildEnvelopesSlivers(
                primaryText: primaryText,
                secondaryText: secondaryText,
                dividerColor: dividerColor,
                systemRed: systemRed,
                systemGreen: systemGreen,
                totalIncomeCents: totalIncomeCents,
                totalExpenseCents: totalExpenseCents,
                leftToBudgetCents: leftToBudgetCents,
                leftPct: leftPct,
                incomePods: incomePods,
                incomeSources: _incomeSources,
                incomePodBalanceCents: incomePodBalanceCents,
                expensePods: expensePods,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEnvelopesSlivers({
    required Color primaryText,
    required Color secondaryText,
    required Color dividerColor,
    required Color systemRed,
    required Color systemGreen,
    required int totalIncomeCents,
    required int totalExpenseCents,
    required int leftToBudgetCents,
    required double? leftPct,
    required List<Pod> incomePods,
    required List<IncomeSource> incomeSources,
    required int? incomePodBalanceCents,
    required List<Pod> expensePods,
  }) {
    final leftLabel =
        leftToBudgetCents < 0 ? 'Over budget by' : 'Unassigned';
    final leftColor = leftToBudgetCents < 0 ? systemRed : systemGreen;

    Widget summaryRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? primaryText,
              ),
            ),
          ],
        ),
      );
    }

    final summary = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              summaryRow(
                'Total Income',
                _formatCents(totalIncomeCents),
              ),
              if (incomePodBalanceCents != null)
                summaryRow(
                  'Income Pod Balance',
                  _formatCents(incomePodBalanceCents),
                ),
              summaryRow(
                'Total Budgeted Expenses',
                _formatCents(totalExpenseCents),
              ),
              Container(height: 1, color: dividerColor),
              summaryRow(
                leftLabel,
                _formatCents(leftToBudgetCents.abs()),
                valueColor: leftColor,
              ),
              if (totalIncomeCents > 0)
                summaryRow(
                  'Left to Budget %',
                  _formatPct(leftPct),
                  valueColor: leftColor,
                ),
            ],
          ),
        ),
      ),
    );

    SliverToBoxAdapter _sectionHeaderSliver({
      required String title,
      required String metaText,
      required String col1,
      required String col3,
      required double col2Width,
      required double col3Width,
    }) {
      final markerKey = _sectionMarkerKeys[title];
      final pillColor = _sectionColor(title);
      return SliverToBoxAdapter(
        child: KeyedSubtree(
          key: markerKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: pillColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        col1,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                          color: secondaryText,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: col2Width,
                      child: Text(
                        'BUDGET',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                          color: secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: col3Width,
                      child: Text(
                        col3,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(height: 1, color: dividerColor),
              ],
            ),
          ),
        ),
      );
    }

    List<Widget> buildSection({
      required String title,
      required List<Pod> pods,
      required int totalIncomeCents,
    }) {
      if (pods.isEmpty) return const [];

      final sectionBudgeted = _sumBudgeted(pods);
      final pct = _pctOfIncome(partCents: sectionBudgeted, incomeCents: totalIncomeCents);
      const budgetColWidth = 116.0;
      const balanceColWidth = 104.0;

      final pctText = (totalIncomeCents > 0 && title != 'Income')
          ? '${_formatPct(pct)} of income'
          : null;
      final metaText = <String>[
        '${pods.length} envelopes',
        if (pctText != null) pctText,
      ].join(' • ');

      final balanceTotalCents = _sumBalances(pods);
      final totalsLabel = '$title Totals';

      final totalsBg = CupertinoColors.systemGrey6.resolveFrom(context);

      final list = SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
            final totalsIdx = pods.length;
            final spacerIdx = pods.length + 1;

            if (index == spacerIdx) return const SizedBox(height: 2);

            if (index == totalsIdx) {
              final budgetText = _formatCents(sectionBudgeted);
              final balanceText = balanceTotalCents == null
                  ? '—'
                  : _formatCents(balanceTotalCents);

              return Column(
                children: [
                  Container(
                    color: totalsBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: DefaultTextStyle(
                      style: TextStyle(color: primaryText),
                      child: Row(
                        children: [
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              totalsLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: budgetColWidth,
                            child: Text(
                              budgetText,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: balanceColWidth,
                            child: Text(
                              balanceText,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: secondaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 1, color: dividerColor),
                ],
              );
            }

            final pod = pods[index];
            final budgeted = pod.settings?.budgetedAmountCents;
            final budgetedText = budgeted == null ? '—' : _formatCents(budgeted);

            final balanceText = pod.balanceError != null
                        ? '—'
                        : _formatCents(pod.balanceCents);

                    return Column(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: Size.zero,
                          pressedOpacity: 0.65,
                          alignment: Alignment.centerLeft,
                  onPressed: () => _editPodBudget(pod),
                          child: DefaultTextStyle(
                            style: TextStyle(color: primaryText),
                            child: Row(
                              children: [
                                const SizedBox(width: 2),
                                Expanded(
                          child: Text(
                                        pod.name,
                                        style: TextStyle(
                              fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: primaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: budgetColWidth,
                          child: Text(
                            budgetedText,
                            textAlign: TextAlign.right,
                                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: balanceColWidth,
                          child: Text(
                            balanceText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                                            color: secondaryText,
                                          ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconTheme(
                          data: IconThemeData(color: secondaryText),
                          child: const PixelIcon(
                            'assets/icons/ui/chevron_right.svg',
                            semanticLabel: 'Edit',
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 1, color: dividerColor),
              ],
            );
          }, childCount: pods.length + 2),
        ),
      );

      return [
        _sectionHeaderSliver(
          title: title,
          metaText: metaText,
          col1: 'ENVELOPE',
          col3: 'BALANCE',
          col2Width: budgetColWidth,
          col3Width: balanceColWidth,
        ),
        list,
      ];
    }

    List<Widget> buildIncomeSourcesSection({
      required List<IncomeSource> sources,
      required int totalIncomeCents,
    }) {
      const budgetColWidth = 116.0;
      const leftColWidth = 104.0;

      final sectionBudgeted = _sumIncomeSourceBudgeted(sources);
      final metaText = '${sources.length} sources';

      final list = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final sourcesCount = sources.length;
            // rows: sources..., totals, + new, spacer
            final totalsIdx = sourcesCount;
            final newIdx = sourcesCount + 1;
            final spacerIdx = sourcesCount + 2;

            if (index == spacerIdx) return const SizedBox(height: 2);

            Widget row({
              required String title,
              required String budgetText,
              required String leftText,
              VoidCallback? onPressed,
              bool bold = false,
              bool chevron = true,
            }) {
              return Column(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: Size.zero,
                    pressedOpacity: 0.65,
                    alignment: Alignment.centerLeft,
                    onPressed: onPressed,
                    child: DefaultTextStyle(
                      style: TextStyle(color: primaryText),
                      child: Row(
                        children: [
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    bold ? FontWeight.w800 : FontWeight.w600,
                                color: onPressed == null
                                    ? secondaryText
                                    : primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                          SizedBox(
                            width: budgetColWidth,
                            child: Text(
                              budgetText,
                              textAlign: TextAlign.right,
                                  style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    bold ? FontWeight.w800 : FontWeight.w700,
                                color: onPressed == null
                                    ? secondaryText
                                    : primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: leftColWidth,
                            child: Text(
                              leftText,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    bold ? FontWeight.w800 : FontWeight.w700,
                                color: secondaryText,
                              ),
                            ),
                          ),
                          if (chevron && onPressed != null) ...[
                                const SizedBox(width: 6),
                                IconTheme(
                                  data: IconThemeData(color: secondaryText),
                                  child: const PixelIcon(
                                    'assets/icons/ui/chevron_right.svg',
                                    semanticLabel: 'Edit',
                                    size: 18,
                                  ),
                                ),
                          ],
                              ],
                            ),
                          ),
                        ),
                        Container(height: 1, color: dividerColor),
                      ],
                    );
            }

            if (index < sourcesCount) {
              final s = sources[index];
              final budgetText = _formatCents(s.budgetedAmountCents);
              // v1: without per-source actuals, left-to-earn equals planned.
              final leftText = _formatCents(s.budgetedAmountCents);
              return row(
                title: s.name,
                budgetText: budgetText,
                leftText: leftText,
                onPressed: () => _editIncomeSource(s),
              );
            }

            if (index == totalsIdx) {
              final totalText = _formatCents(sectionBudgeted);
              return row(
                title: 'Income Totals',
                budgetText: totalText,
                leftText: totalText,
                onPressed: null,
                bold: true,
                chevron: false,
              );
            }

            if (index == newIdx) {
              return Column(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: Size.zero,
                    pressedOpacity: 0.65,
                    alignment: Alignment.centerLeft,
                    onPressed: () => _editIncomeSource(null),
                    child: SizedBox(
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+ New',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: dividerColor),
                ],
              );
            }

            return const SizedBox.shrink();
          }, childCount: sources.length + 3),
        ),
      );

      return [
        _sectionHeaderSliver(
          title: 'Income',
          metaText: metaText,
          col1: 'SOURCE',
          col3: 'LEFT TO EARN',
          col2Width: budgetColWidth,
          col3Width: leftColWidth,
        ),
        list,
      ];
    }

    const budgetColWidth = 116.0;
    const rightColWidth = 104.0;

    final leftPctText = totalIncomeCents > 0 ? _formatPct(leftPct) : '—';
    final unassignedText = _formatCents(leftToBudgetCents.abs());

    int activeSectionBudgetedCents = 0;
    String activeCountText = '0 envelopes';
    String? activePctText;
    String activeCol1 = 'ENVELOPE';
    String activeCol3 = 'BALANCE';

    if (_activeStickySection == 'Income') {
      final incomeUsesSources = incomeSources.isNotEmpty || incomePods.isEmpty;
      if (incomeUsesSources) {
        activeSectionBudgetedCents = _sumIncomeSourceBudgeted(incomeSources);
        activeCountText = '${incomeSources.length} sources';
        activeCol1 = 'SOURCE';
        activeCol3 = 'LEFT TO EARN';
      } else {
        activeSectionBudgetedCents = _sumBudgeted(incomePods);
        activeCountText = '${incomePods.length} envelopes';
      }
    } else if (_expenseSections.contains(_activeStickySection)) {
      final pods = expensePods
          .where((p) => p.settings?.category == _activeStickySection)
          .toList(growable: false);
      activeSectionBudgetedCents = _sumBudgeted(pods);
      activeCountText = '${pods.length} envelopes';
      if (totalIncomeCents > 0) {
        final pct = _pctOfIncome(
          partCents: activeSectionBudgetedCents,
          incomeCents: totalIncomeCents,
        );
        activePctText = '${_formatPct(pct)} of income';
      }
    } else if (_activeStickySection == 'Uncategorized') {
      final pods = expensePods
          .where((p) {
            final c = p.settings?.category;
            return c == null || c.isEmpty || !_expenseSections.contains(c);
          })
          .toList(growable: false);
      activeSectionBudgetedCents = _sumBudgeted(pods);
      activeCountText = '${pods.length} envelopes';
      if (totalIncomeCents > 0) {
        final pct = _pctOfIncome(
          partCents: activeSectionBudgetedCents,
          incomeCents: totalIncomeCents,
        );
        activePctText = '${_formatPct(pct)} of income';
      }
    }

    final stickyMetaText = <String>[
      activeCountText,
      if (activePctText != null) activePctText,
    ].join(' • ');

    final budgetSignalSticky = SliverPersistentHeader(
      pinned: true,
      delegate: _BudgetSignalHeaderDelegate(
        leftLabel: leftLabel,
        unassignedText: unassignedText,
        leftPctText: leftPctText,
        leftColor: leftColor,
        primaryText: primaryText,
        secondaryText: secondaryText,
        dividerColor: dividerColor,
      ),
    );

    final sticky = SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        title: _activeStickySection,
        pillColor: _sectionColor(_activeStickySection),
        metaText: stickyMetaText,
        sectionTotalText: null,
        col1: activeCol1,
        col3: activeCol3,
        col2Width: budgetColWidth,
        col3Width: rightColWidth,
        primaryText: primaryText,
        secondaryText: secondaryText,
        dividerColor: dividerColor,
      ),
    );

    final slivers = <Widget>[budgetSignalSticky, sticky, summary];

    // Income section
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 6)));
    if (incomeSources.isNotEmpty) {
      slivers.addAll(
        buildIncomeSourcesSection(
          sources: incomeSources,
          totalIncomeCents: totalIncomeCents,
        ),
      );
    } else {
      if (incomePods.isEmpty) {
        // No Income envelopes selected yet — still show the sources UI so "+ New"
        // doesn't float without a header.
        slivers.addAll(
          buildIncomeSourcesSection(
            sources: const [],
            totalIncomeCents: totalIncomeCents,
          ),
        );
      } else {
        slivers.addAll(
          buildSection(
            title: 'Income',
            pods: incomePods..sort((a, b) => a.name.compareTo(b.name)),
            totalIncomeCents: totalIncomeCents,
          ),
        );
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: Size.zero,
                    pressedOpacity: 0.65,
                    alignment: Alignment.centerLeft,
                    onPressed: () => _editIncomeSource(null),
                  child: SizedBox(
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+ New',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ),
                  ),
                  Container(height: 1, color: dividerColor),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Expense sections
    for (final section in _expenseSections) {
      final pods = expensePods
          .where((p) => p.settings?.category == section)
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      if (pods.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 22)));
      }
      slivers.addAll(
        buildSection(
          title: section,
          pods: pods,
          totalIncomeCents: totalIncomeCents,
        ),
      );
    }

    // Uncategorized / Other
    final uncategorized = expensePods
        .where((p) {
          final c = p.settings?.category;
          return c == null || c.isEmpty || !_expenseSections.contains(c);
        })
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (uncategorized.isNotEmpty) {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 22)));
    }
    slivers.addAll(
      buildSection(
        title: 'Uncategorized',
        pods: uncategorized,
        totalIncomeCents: totalIncomeCents,
      ),
    );

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
    return slivers;
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.title,
    required this.pillColor,
    required this.metaText,
    required this.sectionTotalText,
    required this.col1,
    required this.col3,
    required this.col2Width,
    required this.col3Width,
    required this.primaryText,
    required this.secondaryText,
    required this.dividerColor,
  });

  static const double height = 74;

  final String title;
  final Color pillColor;
  final String metaText;
  final String? sectionTotalText;
  final String col1;
  final String col3;
  final double col2Width;
  final double col3Width;
  final Color primaryText;
  final Color secondaryText;
  final Color dividerColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: pillColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: pillColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (sectionTotalText != null && sectionTotalText!.isNotEmpty)
                    Text(
                      sectionTotalText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      col1,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: col2Width,
                    child: Text(
                      'BUDGET',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: col3Width,
                    child: Text(
                      col3,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(height: 1, color: dividerColor),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        pillColor != oldDelegate.pillColor ||
        metaText != oldDelegate.metaText ||
        sectionTotalText != oldDelegate.sectionTotalText ||
        col1 != oldDelegate.col1 ||
        col3 != oldDelegate.col3 ||
        col2Width != oldDelegate.col2Width ||
        col3Width != oldDelegate.col3Width ||
        primaryText != oldDelegate.primaryText ||
        secondaryText != oldDelegate.secondaryText ||
        dividerColor != oldDelegate.dividerColor;
  }
}

class _BudgetSignalHeaderDelegate extends SliverPersistentHeaderDelegate {
  _BudgetSignalHeaderDelegate({
    required this.leftLabel,
    required this.unassignedText,
    required this.leftPctText,
    required this.leftColor,
    required this.primaryText,
    required this.secondaryText,
    required this.dividerColor,
  });

  static const double height = 44;

  final String leftLabel;
  final String unassignedText;
  final String leftPctText;
  final Color leftColor;
  final Color primaryText;
  final Color secondaryText;
  final Color dividerColor;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);

    Widget chip({required String text}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: leftColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: leftColor,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                chip(text: '$leftLabel $unassignedText'),
                const SizedBox(width: 10),
                chip(text: 'Left $leftPctText'),
                const Spacer(),
              ],
            ),
          ),
          Container(height: 1, color: dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BudgetSignalHeaderDelegate oldDelegate) {
    return leftLabel != oldDelegate.leftLabel ||
        unassignedText != oldDelegate.unassignedText ||
        leftPctText != oldDelegate.leftPctText ||
        leftColor != oldDelegate.leftColor ||
        primaryText != oldDelegate.primaryText ||
        secondaryText != oldDelegate.secondaryText ||
        dividerColor != oldDelegate.dividerColor;
  }
}

class _IncomeSourceSheet extends StatefulWidget {
  const _IncomeSourceSheet({
    required this.source,
    required this.onSave,
    required this.onArchive,
  });

  final IncomeSource? source;
  final Future<void> Function({
    required String name,
    required int budgetedAmountCents,
  })
  onSave;

  /// When non-null, enables an Archive action (soft delete).
  final Future<void> Function()? onArchive;

  @override
  State<_IncomeSourceSheet> createState() => _IncomeSourceSheetState();
}

class _IncomeSourceSheetState extends State<_IncomeSourceSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.source?.name ?? '');

  late final TextEditingController _budgeted = TextEditingController(
    text: widget.source == null
        ? ''
        : (widget.source!.budgetedAmountCents / 100).toStringAsFixed(2),
  );

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _budgetFocus = FocusNode();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_saving) return;
      if (_name.text.trim().isEmpty) {
        _nameFocus.requestFocus();
      } else {
        _budgetFocus.requestFocus();
        final t = _budgeted.text;
        if (t.isNotEmpty) {
          _budgeted.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
        }
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _budgeted.dispose();
    _nameFocus.dispose();
    _budgetFocus.dispose();
    super.dispose();
  }

  int _parseMoneyToCents(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    final cleaned = s.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null) return 0;
    return (v * 100).round();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showGlassToast(context, 'Name is required.');
      _nameFocus.requestFocus();
      return;
    }

    setState(() => _saving = true);
    try {
      final budgetedCents = _parseMoneyToCents(_budgeted.text);
      await widget.onSave(name: name, budgetedAmountCents: budgetedCents);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Save failed: $e');
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmArchive() async {
    final onArchive = widget.onArchive;
    if (onArchive == null) return;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Archive income source?'),
          message: const Text('This removes it from budgets but keeps history.'),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await onArchive();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Archive failed: $e');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final reduceMotion = GlassAdaptive.reduceMotionOf(context);
    final keyboardBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final baseHeight = screenHeight * 0.48;
    final maxHeight = screenHeight - keyboardBottomInset - 24;
    final height = (baseHeight > maxHeight ? maxHeight : baseHeight).clamp(
      260.0,
      screenHeight,
    );

    final isEditing = widget.source != null;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardBottomInset),
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
                          const SizedBox(width: 34),
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit income source' : 'New income source',
                              textAlign: TextAlign.center,
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .navTitleTextStyle,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed:
                                _saving ? null : () => Navigator.of(context).pop(false),
                            child: const Icon(CupertinoIcons.xmark, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          Text(
                            'Name',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: _name,
                            focusNode: _nameFocus,
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _budgetFocus.requestFocus(),
                            padding: const EdgeInsets.all(12),
                            placeholder: 'e.g. Redline - Sept',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Budgeted (monthly)',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: _budgeted,
                            focusNode: _budgetFocus,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: false,
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            padding: const EdgeInsets.all(12),
                            placeholder: '0.00',
                          ),
                          const SizedBox(height: 14),
                          if (widget.onArchive != null)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _saving ? null : _confirmArchive,
                              child: Text(
                                'Archive',
                                style: TextStyle(
                                  color: CupertinoColors.systemRed.resolveFrom(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: CupertinoColors.separator.resolveFrom(context),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const CupertinoActivityIndicator(radius: 10)
                              : const Text('Save'),
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

class _PodBudgetSheet extends StatefulWidget {
  const _PodBudgetSheet({
    required this.pod,
    required this.sectionOptions,
    required this.onSave,
  });

  final Pod pod;
  final List<String> sectionOptions;
  final Future<void> Function({
    required String? category,
    required int? budgetedAmountCents,
  })
  onSave;

  @override
  State<_PodBudgetSheet> createState() => _PodBudgetSheetState();
}

class _PodBudgetSheetState extends State<_PodBudgetSheet> {
  late String? _category = widget.pod.settings?.category;
  late final TextEditingController _budgeted = TextEditingController(
    text: widget.pod.settings?.budgetedAmountCents == null
        ? ''
        : (widget.pod.settings!.budgetedAmountCents! / 100).toStringAsFixed(2),
  );
  final FocusNode _budgetedFocus = FocusNode();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_saving) return;
      _budgetedFocus.requestFocus();
      final t = _budgeted.text;
      if (t.isEmpty) return;
      _budgeted.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
    });
  }

  @override
  void dispose() {
    _budgeted.dispose();
    _budgetedFocus.dispose();
    super.dispose();
  }

  int? _parseMoneyToCents(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    if (cleaned.isEmpty) return null;
    final v = double.tryParse(cleaned);
    if (v == null) return null;
    return (v * 100).round();
  }

  String _formatCents(int cents) {
    final neg = cents < 0;
    var v = cents.abs();
    final dollars = v ~/ 100;
    final rem = v % 100;
    final s = dollars.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      final nextFromEnd = idxFromEnd - 1;
      if (nextFromEnd > 0 && nextFromEnd % 3 == 0) buf.write(',');
    }
    return '${neg ? '-' : ''}\$${buf.toString()}.${rem.toString().padLeft(2, '0')}';
  }

  String _displayCategory() {
    final c = _category;
    if (c == null) return 'Uncategorized';
    if (c.isEmpty) return 'Uncategorized';
    return c;
  }

  Widget _budgetPreview({
    required BuildContext context,
    required Color secondary,
  }) {
    return AnimatedBuilder(
      animation: _budgeted,
      builder: (context, _) {
        final availableCents =
            widget.pod.balanceError == null ? widget.pod.balanceCents : null;
        final previewBg = CupertinoColors.systemGrey6.resolveFrom(context);
        final divider = CupertinoColors.separator.resolveFrom(context);

        final availableText = availableCents == null
            ? '—'
            : _formatCents(availableCents);

        return Container(
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: divider),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Available',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                availableText,
                style: TextStyle(
                  color: secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSection() async {
    final selected = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (context) {
        // Match the “menu sheet” vibe: avoid purple/primaryColor-tinted actions.
        final label = CupertinoColors.label.resolveFrom(context);
        return CupertinoTheme(
          data: CupertinoTheme.of(context).copyWith(primaryColor: label),
          child: CupertinoActionSheet(
            title: const Text('Category'),
            actions: [
              ...widget.sectionOptions.map(
                (c) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(c),
                  child: Text(c),
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected == null) return;
    setState(() => _category = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final budgetedCents = _parseMoneyToCents(_budgeted.text);
      await widget.onSave(
        category: _category,
        budgetedAmountCents: budgetedCents,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Save failed: $e');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final reduceMotion = GlassAdaptive.reduceMotionOf(context);
    final keyboardBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final baseHeight = screenHeight * 0.52;
    // When the keyboard is up, keep the sheet fully visible by shrinking it to
    // fit above the keyboard + our outer padding.
    final maxHeight = screenHeight - keyboardBottomInset - 24;
    final height = (baseHeight > maxHeight ? maxHeight : baseHeight).clamp(
      260.0,
      screenHeight,
    );

    // Match the user menu sheet styling (GlassSurface + handle + header).
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        // Lift the entire sheet above the keyboard.
        padding: EdgeInsets.only(bottom: keyboardBottomInset),
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
                        const SizedBox(width: 34),
                        Expanded(
                          child: Text(
                              'Envelope budget',
                            textAlign: TextAlign.center,
                            style: CupertinoTheme.of(
                              context,
                            ).textTheme.navTitleTextStyle,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
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
                      child: KeyedSubtree(
                        key: ValueKey(_saving),
                          child: Column(
                            children: [
                              Expanded(
                        child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                          children: [
                            Text(
                              widget.pod.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                                    const SizedBox(height: 12),
                                  Text(
                                    'Budgeted (monthly)',
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  CupertinoTextField(
                                    controller: _budgeted,
                                    focusNode: _budgetedFocus,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: false,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _save(),
                                    padding: const EdgeInsets.all(12),
                                    placeholder: '0.00',
                                  ),
                                  const SizedBox(height: 10),
                                  _budgetPreview(
                                    context: context,
                                    secondary: secondary,
                                  ),
                                  const SizedBox(height: 14),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                                    onPressed: _saving ? null : _pickSection,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Category',
                                        style: TextStyle(
                                                color: secondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                            _displayCategory(),
                                      style: TextStyle(
                                        color: secondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                          const SizedBox(width: 6),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                            size: 16,
                                      color: CupertinoColors.tertiaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                                ],
                              ),
                            ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: CupertinoColors.separator
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: CupertinoButton.filled(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                        ? const CupertinoActivityIndicator(
                                            radius: 10,
                                          )
                                  : const Text('Save'),
                                  ),
                                ),
                            ),
                          ],
                        ),
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
