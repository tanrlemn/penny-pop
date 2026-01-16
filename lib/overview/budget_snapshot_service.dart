import 'package:penny_pop_app/income/income_models.dart';
import 'package:penny_pop_app/income/income_service.dart';
import 'package:penny_pop_app/overview/budget_snapshot.dart';
import 'package:penny_pop_app/pods/pod_models.dart';
import 'package:penny_pop_app/pods/pods_service.dart';

class BudgetSnapshotService {
  BudgetSnapshotService({
    PodsService? podsService,
    IncomeSourcesService? incomeSourcesService,
  })  : _podsService = podsService ?? PodsService(),
        _incomeSourcesService = incomeSourcesService ?? IncomeSourcesService();

  final PodsService _podsService;
  final IncomeSourcesService _incomeSourcesService;

  static const List<String> expenseSections = <String>[
    'Savings',
    'Kiddos',
    'Necessities',
    'Pressing',
    'Discretionary',
  ];

  bool _isIncome(Pod p) => p.settings?.category == 'Income';

  int _budgetedCents(Pod p) => p.settings?.budgetedAmountCents ?? 0;

  int _sumBudgeted(Iterable<Pod> pods) =>
      pods.fold<int>(0, (sum, p) => sum + _budgetedCents(p));

  int _sumIncomeSourceBudgeted(Iterable<IncomeSource> sources) =>
      sources.fold<int>(0, (sum, s) => sum + s.budgetedAmountCents);

  Future<BudgetSnapshot> load({required String householdId}) async {
    final pods = await _podsService.listPodsWithSettings(householdId: householdId);

    List<IncomeSource> incomeSources = const [];
    try {
      incomeSources = await _incomeSourcesService.listIncomeSources(
        householdId: householdId,
      );
    } catch (_) {
      // Income sources are optional; keep snapshot usable.
      incomeSources = const [];
    }

    final incomePods = pods.where(_isIncome).toList(growable: false);
    final expensePods = pods.where((p) => !_isIncome(p)).toList(growable: false);

    final totalIncomeCents = incomeSources.isNotEmpty
        ? _sumIncomeSourceBudgeted(incomeSources)
        : _sumBudgeted(incomePods);
    final totalExpenseCents = _sumBudgeted(expensePods);
    final leftToBudgetCents = totalIncomeCents - totalExpenseCents;

    final missingBudgetCount =
        expensePods.where((p) => p.settings?.budgetedAmountCents == null).length;

    final uncategorizedCount = expensePods.where((p) {
      final c = p.settings?.category;
      return c == null || c.isEmpty || !expenseSections.contains(c);
    }).length;

    DateTime? latestBalanceUpdatedAt;
    try {
      latestBalanceUpdatedAt =
          await _podsService.latestBalanceUpdatedAt(householdId: householdId);
    } catch (_) {
      latestBalanceUpdatedAt = null;
    }

    return BudgetSnapshot(
      pods: pods,
      incomeSources: incomeSources,
      totalIncomeCents: totalIncomeCents,
      totalExpenseCents: totalExpenseCents,
      leftToBudgetCents: leftToBudgetCents,
      missingBudgetCount: missingBudgetCount,
      uncategorizedCount: uncategorizedCount,
      latestBalanceUpdatedAt: latestBalanceUpdatedAt,
    );
  }
}

