import 'package:penny_pop_app/pods/pod_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PodsService {
  PodsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Pod>> listPods({
    required String householdId,
  }) async {
    var query = _supabase.from('pods').select(
      'id,household_id,sequence_account_id,name,is_active,last_seen_at,balance_amount_in_cents,balance_error,pod_settings(category,notes)',
    ).eq('household_id', householdId);

    // Active only by default for the app UI. Inactive pods are retained for history.
    query = query.eq('is_active', true);

    final data = await query.order('name', ascending: true);
    final rows = (data as List).cast<Map>().map((r) => r.cast<String, dynamic>());
    return rows.map(Pod.fromRow).toList(growable: false);
  }

  Future<DateTime?> latestBalanceUpdatedAt({required String householdId}) async {
    final data = await _supabase
        .from('pods')
        .select('balance_updated_at')
        .eq('household_id', householdId)
        .eq('is_active', true)
        .order('balance_updated_at', ascending: false)
        .limit(1);

    if (data.isNotEmpty) {
      final row = (data.first as Map).cast<String, dynamic>();
      final v = row['balance_updated_at'];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }
    return null;
  }

  Future<Map<String, dynamic>?> syncPodsFromSequence() async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not signed in');
    }
    // Ensure the underlying FunctionsClient has the auth header set.
    _supabase.functions.setAuth(token);

    final authHeaders = <String, String>{
      // Some gateways/clients can be picky; send both casings.
      'authorization': 'Bearer $token',
      'Authorization': 'Bearer $token',
    };

    final resp = await _supabase.functions.invoke(
      'sync-pods',
      headers: authHeaders,
      body: <String, dynamic>{'access_token': token},
    );
    return resp.data as Map<String, dynamic>?;
  }

  Future<void> upsertPodSettings({
    required String podId,
    String? category,
    String? notes,
  }) async {
    await _supabase.from('pod_settings').upsert({
      'pod_id': podId,
      'category': category,
      'notes': notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}


