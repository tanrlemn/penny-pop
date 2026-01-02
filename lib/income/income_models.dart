class IncomeSource {
  const IncomeSource({
    required this.id,
    required this.householdId,
    required this.name,
    required this.budgetedAmountCents,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String householdId;
  final String name;
  final int budgetedAmountCents;
  final bool isActive;
  final int? sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  static IncomeSource fromRow(Map<String, dynamic> row) {
    final b = row['budgeted_amount_in_cents'];
    int budgetedCents = 0;
    if (b is int) {
      budgetedCents = b;
    } else if (b is num) {
      budgetedCents = b.toInt();
    } else if (b != null) {
      budgetedCents = int.tryParse(b.toString()) ?? 0;
    }

    final so = row['sort_order'];
    int? sortOrder;
    if (so is int) {
      sortOrder = so;
    } else if (so is num) {
      sortOrder = so.toInt();
    } else if (so != null) {
      sortOrder = int.tryParse(so.toString());
    }

    return IncomeSource(
      id: row['id'].toString(),
      householdId: row['household_id'].toString(),
      name: row['name']?.toString() ?? '',
      budgetedAmountCents: budgetedCents,
      isActive: row['is_active'] == true,
      sortOrder: sortOrder,
      createdAt: DateTime.parse(row['created_at'].toString()),
      updatedAt: DateTime.parse(row['updated_at'].toString()),
    );
  }
}


