import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:penny_pop_app/households/active_household.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotAuthorizedException implements Exception {
  const NotAuthorizedException([this.message = 'Not authorized']);

  final String message;

  @override
  String toString() => message;
}

class HouseholdService {
  HouseholdService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  bool _looksLikeNotAuthorized(Object e) {
    // PostgREST wraps raised exceptions; keep this loose and message-based.
    final s = e.toString().toLowerCase();
    return s.contains('not authorized');
  }

  Future<ActiveHousehold> ensureActiveHousehold() async {
    dynamic data;
    try {
      data = await _supabase.rpc('ensure_active_household');
    } catch (e) {
      if (_looksLikeNotAuthorized(e)) {
        throw NotAuthorizedException(e.toString());
      }
      rethrow;
    }

    Map<String, dynamic>? row;
    if (data is List && data.isNotEmpty) {
      row = (data.first as Map).cast<String, dynamic>();
    } else if (data is Map) {
      row = data.cast<String, dynamic>();
    }

    if (row == null) {
      throw Exception('Unexpected RPC response for ensure_active_household: $data');
    }

    final id = row['household_id']?.toString();
    final name = row['household_name']?.toString();
    final role = row['role']?.toString();

    if (id == null || name == null || role == null) {
      throw Exception('Missing fields in ensure_active_household response: $row');
    }

    return ActiveHousehold(id: id, name: name, role: role);
  }

  Future<String?> addHouseholdMemberByEmail({
    required String householdId,
    required String email,
  }) async {
    final data = await _supabase.rpc(
      'add_household_member_by_email',
      params: {'p_household_id': householdId, 'p_email': email},
    );

    // Function returns a row (or list of rows) with:
    // - out_household_id
    // - out_user_id
    // - out_role
    //
    // We don't need the result for core behavior, but callers can use it for UX.
    Map<String, dynamic>? row;
    if (data is List && data.isNotEmpty) {
      row = (data.first as Map).cast<String, dynamic>();
    } else if (data is Map) {
      row = data.cast<String, dynamic>();
    }

    if (row == null) return null;
    return row['out_user_id']?.toString();
  }
}

class ActiveHouseholdController extends ChangeNotifier {
  ActiveHouseholdController({HouseholdService? service})
      : _service = service ?? HouseholdService() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Fire-and-forget on startup; listeners will update when loaded.
      unawaited(ensureLoaded());
    }
  }

  final HouseholdService _service;
  late final StreamSubscription<AuthState> _sub;

  ActiveHousehold? _active;
  bool _isLoading = false;
  Object? _error;
  String? _lastUserId;

  ActiveHousehold? get active => _active;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> ensureLoaded() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      clear();
      return;
    }
    if (_active != null && _lastUserId == userId) return;
    await refresh();
  }

  Future<void> refresh() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) {
      clear();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final active = await _service.ensureActiveHousehold();
      _active = active;
      _lastUserId = userId;
    } catch (e) {
      _error = e;
      // If the user is signed in but not authorized for the family household,
      // treat that as a stable state (don't keep re-attempting on rebuilds).
      if (e is NotAuthorizedException) {
        _active = null;
        _lastUserId = userId;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _active = null;
    _error = null;
    _isLoading = false;
    _lastUserId = null;
    notifyListeners();
  }

  void _onAuthChange(AuthState state) {
    final session = state.session;
    final userId = session?.user.id;
    if (userId == null) {
      clear();
      return;
    }
    if (_lastUserId == userId) return;
    unawaited(refresh());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}


