import 'package:penny_pop_app/income/income_models.dart';
import 'package:penny_pop_app/pods/pod_models.dart';

enum BudgetHealthStatus {
  onTrack,
  needsAssigning,
  overBudget,
}

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.pods,
    required this.incomeSources,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.leftToBudgetCents,
    required this.missingBudgetCount,
    required this.uncategorizedCount,
    required this.latestBalanceUpdatedAt,
  });

  final List<Pod> pods;
  final List<IncomeSource> incomeSources;

  final int totalIncomeCents;
  final int totalExpenseCents;
  final int leftToBudgetCents;

  /// Count of expense pods whose `budgetedAmountCents` is null (not “0”).
  final int missingBudgetCount;

  /// Count of expense pods with missing/unknown category (not in known sections).
  final int uncategorizedCount;

  /// Latest known `balance_updated_at` across pods (if available).
  final DateTime? latestBalanceUpdatedAt;

  BudgetHealthStatus get healthStatus {
    if (leftToBudgetCents < 0) return BudgetHealthStatus.overBudget;
    if (leftToBudgetCents > 0) return BudgetHealthStatus.needsAssigning;
    return BudgetHealthStatus.onTrack;
  }
}

