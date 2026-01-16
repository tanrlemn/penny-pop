class ProposedAction {
  ProposedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.status,
    this.title,
    this.summary,
    this.confidence,
  });

  final String id;
  final String type;
  final ActionPayload? payload;
  final ActionStatus status;
  final String? title;
  final String? summary;
  final double? confidence;

  BudgetTransferPayload? get budgetTransferPayload =>
      payload is BudgetTransferPayload ? payload as BudgetTransferPayload : null;

  BudgetRepairRestoreDonorPayload? get budgetRepairRestoreDonorPayload =>
      payload is BudgetRepairRestoreDonorPayload
          ? payload as BudgetRepairRestoreDonorPayload
          : null;

  ProposedAction copyWith({ActionStatus? status}) {
    return ProposedAction(
      id: id,
      type: type,
      payload: payload,
      status: status ?? this.status,
      title: title,
      summary: summary,
      confidence: confidence,
    );
  }

  factory ProposedAction.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final id = json['id']?.toString();
    final type = json['type']?.toString() ?? json['kind']?.toString() ?? 'unknown';
    final payloadJson = (json['payload'] is Map)
        ? (json['payload'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final payload = switch (type) {
      'budget_transfer' => BudgetTransferPayload.fromJson(payloadJson),
      'request_transfer' => BudgetTransferPayload.fromJson(payloadJson),
      'budget_repair_restore_donor' =>
        BudgetRepairRestoreDonorPayload.fromJson(payloadJson),
      _ => null,
    };
    final status = ActionStatus.fromString(json['status']?.toString());
    final title = json['title']?.toString();
    final summary = json['summary']?.toString();
    final confidence = _parseConfidence(json['confidence']);
    return ProposedAction(
      id: (id == null || id.isEmpty) ? fallbackId : id,
      type: type,
      payload: payload,
      status: status,
      title: (title == null || title.trim().isEmpty) ? null : title.trim(),
      summary: (summary == null || summary.trim().isEmpty) ? null : summary.trim(),
      confidence: confidence,
    );
  }
}

enum ActionStatus {
  proposed,
  applied,
  ignored;

  static ActionStatus fromString(String? raw) {
    switch (raw) {
      case 'applied':
        return ActionStatus.applied;
      case 'ignored':
        return ActionStatus.ignored;
      case 'proposed':
        return ActionStatus.proposed;
      default:
        return ActionStatus.proposed;
    }
  }
}

sealed class ActionPayload {
  const ActionPayload();
}

class BudgetTransferPayload extends ActionPayload {
  const BudgetTransferPayload({
    required this.amountInCents,
    required this.fromPodName,
    required this.toPodName,
  });

  final int? amountInCents;
  final String? fromPodName;
  final String? toPodName;

  factory BudgetTransferPayload.fromJson(Map<String, dynamic> json) {
    return BudgetTransferPayload(
      amountInCents: _parseCents(json['amount_in_cents']),
      fromPodName: json['from_pod_name']?.toString(),
      toPodName: json['to_pod_name']?.toString(),
    );
  }
}

class BudgetRepairRestoreDonorPayload extends ActionPayload {
  const BudgetRepairRestoreDonorPayload({
    required this.amountInCents,
    required this.donorPodId,
    required this.donorPodName,
    required this.fundingPodName,
    required this.optionLabel,
  });

  final int? amountInCents;
  final String? donorPodId;
  final String? donorPodName;
  final String? fundingPodName;
  final String? optionLabel;

  factory BudgetRepairRestoreDonorPayload.fromJson(Map<String, dynamic> json) {
    return BudgetRepairRestoreDonorPayload(
      amountInCents: _parseCents(json['amount_in_cents']),
      donorPodId: json['donor_pod_id']?.toString(),
      donorPodName: json['donor_pod_name']?.toString(),
      fundingPodName: json['funding_pod_name']?.toString(),
      optionLabel: json['option_label']?.toString(),
    );
  }
}

int? _parseCents(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw == null) return null;
  return int.tryParse(raw.toString());
}

double? _parseConfidence(dynamic raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    final parsed = double.tryParse(s);
    if (parsed != null) return parsed;
    switch (s) {
      case 'high':
        return 0.9;
      case 'med':
      case 'medium':
        return 0.6;
      case 'low':
        return 0.3;
      default:
        return null;
    }
  }
  return null;
}
