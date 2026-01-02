import 'package:flutter/cupertino.dart';
import 'package:penny_pop_app/app/penny_pop_scope.dart';
import 'package:penny_pop_app/design/glass/glass.dart';
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

  bool _loading = false;
  bool _syncing = false;
  Object? _error;
  List<Pod> _pods = const [];

  String? _lastHouseholdId;
  DateTime? _lastAutoSyncAttemptAt;
  String? _lastAutoSyncHouseholdId;

  static const _categories = <String>[
    'Savings',
    'Kiddos',
    'Necessities',
    'Pressing',
    'Discretionary',
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
      if (!mounted) return;
      setState(() => _pods = pods);
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

  Future<void> _editPodSettings(Pod pod) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) {
        return _PodSettingsSheet(
          pod: pod,
          categories: _categories,
          onSave: ({required String? category, required String? notes}) async {
            await _service.upsertPodSettings(
              podId: pod.id,
              category: category,
              notes: notes,
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

  @override
  Widget build(BuildContext context) {
    final householdController = PennyPopScope.householdOf(context);
    final active = householdController.active;
    final isAdmin = active?.role == 'admin';
    final primaryText = CupertinoColors.label.resolveFrom(context);
    final secondaryText = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dividerColor = CupertinoColors.separator.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pods'),
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
            CupertinoSliverRefreshControl(onRefresh: _onPullToRefresh),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (isAdmin)
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        onPressed: _syncing
                            ? null
                            : () => _syncFromSequence(showFeedback: true),
                        child: _syncing
                            ? const CupertinoActivityIndicator(radius: 10)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  PixelIcon(
                                    'assets/icons/ui/sync.svg',
                                    semanticLabel: 'Sync',
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Sync'),
                                ],
                              ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  isAdmin
                      ? 'Pull to refresh to update balances (or tap Sync).'
                      : 'Ask an admin to Sync pods from Sequence.',
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
                  child: Text('Pods couldn’t load.\n$_error'),
                ),
              )
            else if (_pods.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No pods yet. Tap Sync to import from Sequence.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= _pods.length) {
                      return const SizedBox(height: 80);
                    }

                    final pod = _pods[index];
                    final category = pod.settings?.category;
                    final notes = pod.settings?.notes;
                    final subtitleParts = <String>[
                      if (category != null && category.isNotEmpty) category,
                      if (notes != null && notes.isNotEmpty) notes,
                    ];

                    final amount = pod.balanceError != null
                        ? '—'
                        : _formatCents(pod.balanceCents);

                    return Column(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: Size.zero,
                          pressedOpacity: 0.65,
                          alignment: Alignment.centerLeft,
                          onPressed: () => _editPodSettings(pod),
                          child: DefaultTextStyle(
                            style: TextStyle(color: primaryText),
                            child: Row(
                              children: [
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pod.name,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: primaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitleParts.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitleParts.join(' • '),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: secondaryText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  amount,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
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
                  }, childCount: _pods.length + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PodSettingsSheet extends StatefulWidget {
  const _PodSettingsSheet({
    required this.pod,
    required this.categories,
    required this.onSave,
  });

  final Pod pod;
  final List<String> categories;
  final Future<void> Function({
    required String? category,
    required String? notes,
  })
  onSave;

  @override
  State<_PodSettingsSheet> createState() => _PodSettingsSheetState();
}

class _PodSettingsSheetState extends State<_PodSettingsSheet> {
  late String? _category = widget.pod.settings?.category;
  late final TextEditingController _notes = TextEditingController(
    text: widget.pod.settings?.notes ?? '',
  );

  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
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
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Uncategorized'),
              ),
              ...widget.categories.map(
                (c) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(c),
                  child: Text(c),
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(_category),
              child: const Text('Cancel'),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _category = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notes = _notes.text.trim();
      await widget.onSave(
        category: _category,
        notes: notes.isEmpty ? null : notes,
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
    final height = MediaQuery.sizeOf(context).height * 0.52;

    // Match the user menu sheet styling (GlassSurface + handle + header).
    return SafeArea(
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
                        const SizedBox(width: 34),
                        Expanded(
                          child: Text(
                            'Pod settings',
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
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            Text(
                              widget.pod.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 1,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _saving ? null : _pickCategory,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 24, height: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Category',
                                        style: TextStyle(
                                          color: primary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _category ?? 'Uncategorized',
                                      style: TextStyle(
                                        color: secondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 18,
                                      color: CupertinoColors.tertiaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Notes',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            CupertinoTextField(
                              controller: _notes,
                              enabled: !_saving,
                              minLines: 2,
                              maxLines: 6,
                              padding: const EdgeInsets.all(12),
                            ),
                            const SizedBox(height: 12),
                            CupertinoButton.filled(
                              // Keep filled for affordance, but avoid purple text by keeping explicit content colors above.
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const CupertinoActivityIndicator(radius: 10)
                                  : const Text('Save'),
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
    );
  }
}
