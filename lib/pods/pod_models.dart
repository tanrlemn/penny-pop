class PodSettings {
  const PodSettings({this.category, this.notes});

  final String? category;
  final String? notes;

  static PodSettings? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is Map) {
      final map = json.cast<String, dynamic>();
      return PodSettings(
        category: map['category']?.toString(),
        notes: map['notes']?.toString(),
      );
    }
    return null;
  }
}

class Pod {
  const Pod({
    required this.id,
    required this.householdId,
    required this.sequenceAccountId,
    required this.name,
    required this.isActive,
    required this.lastSeenAt,
    required this.balanceCents,
    required this.balanceError,
    this.settings,
  });

  final String id;
  final String householdId;
  final String sequenceAccountId;
  final String name;
  final bool isActive;
  final DateTime lastSeenAt;
  final int? balanceCents;
  final String? balanceError;
  final PodSettings? settings;

  static Pod fromRow(Map<String, dynamic> row) {
    final settingsJson = row['pod_settings'];
    PodSettings? settings;
    if (settingsJson is List && settingsJson.isNotEmpty) {
      settings = PodSettings.fromJson(settingsJson.first);
    } else {
      settings = PodSettings.fromJson(settingsJson);
    }

    final bc = row['balance_amount_in_cents'];
    int? balanceCents;
    if (bc is int) {
      balanceCents = bc;
    } else if (bc is num) {
      balanceCents = bc.toInt();
    } else if (bc != null) {
      balanceCents = int.tryParse(bc.toString());
    }

    final beRaw = row['balance_error'];
    final balanceError = beRaw == null ? null : beRaw.toString();

    return Pod(
      id: row['id'].toString(),
      householdId: row['household_id'].toString(),
      sequenceAccountId: row['sequence_account_id'].toString(),
      name: row['name'].toString(),
      isActive: row['is_active'] == true,
      lastSeenAt: DateTime.parse(row['last_seen_at'].toString()),
      balanceCents: balanceCents,
      balanceError: balanceError,
      settings: settings,
    );
  }
}


