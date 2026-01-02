import 'package:penny_pop_app/income/income_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeSourcesService {
  IncomeSourcesService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<IncomeSource>> listIncomeSources({
    required String householdId,
    bool activeOnly = true,
  }) async {
    var query = _supabase
        .from('income_sources')
        .select(
          'id,household_id,name,budgeted_amount_in_cents,is_active,sort_order,created_at,updated_at',
        )
        .eq('household_id', householdId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final data = await query
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    final rows = (data as List).cast<Map>().map((r) => r.cast<String, dynamic>());
    return rows.map(IncomeSource.fromRow).toList(growable: false);
  }

  Future<void> upsertIncomeSource({
    String? id,
    required String householdId,
    required String name,
    required int budgetedAmountCents,
    int? sortOrder,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'budgeted_amount_in_cents': budgetedAmountCents,
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _supabase.from('income_sources').upsert(payload);
  }

  Future<void> archiveIncomeSource({required String id}) async {
    await _supabase
        .from('income_sources')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteIncomeSource({required String id}) async {
    await _supabase.from('income_sources').delete().eq('id', id);
  }
}


