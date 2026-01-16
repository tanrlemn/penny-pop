import 'package:penny_pop_app/api/api_errors.dart';

class ChatApiResponse {
  ChatApiResponse({
    required this.assistantText,
    required this.proposedActions,
    this.apiVersion,
    this.entities,
    this.warnings,
    this.debug,
    this.traceId,
  });

  final String assistantText;
  final List<ProposedActionDto> proposedActions;
  final String? apiVersion;
  final Map<String, dynamic>? entities;
  final List<String>? warnings;
  final Map<String, dynamic>? debug;
  final String? traceId;

  factory ChatApiResponse.fromJson(Map<String, dynamic> json) {
    final traceId = _extractTraceId(json);
    try {
      final assistantText =
          _requireNonEmptyString(json['assistantText'], field: 'assistantText');

      // Primary stable contract is `proposedActions`, but keep legacy fallbacks
      // to avoid breaking current deterministic backend variants.
      final rawActions =
          json['proposedActions'] ?? json['actions'] ?? json['actionProposals'];
      final list = _requireList(rawActions, field: 'proposedActions');
      final actions = <ProposedActionDto>[];
      for (var i = 0; i < list.length; i++) {
        final entry = list[i];
        if (entry is Map) {
          actions.add(
            ProposedActionDto.fromJson(
              entry.cast<String, dynamic>(),
              fallbackId: 'action_$i',
            ),
          );
        } else if (entry is String) {
          actions.add(
            ProposedActionDto(
              id: entry,
              type: 'unknown',
              status: 'proposed',
              payload: const <String, dynamic>{},
            ),
          );
        }
      }

      final entities = (json['entities'] is Map)
          ? (json['entities'] as Map).cast<String, dynamic>()
          : null;

      final warnings = _parseWarnings(json['warnings']);
      final debug = (json['debug'] is Map)
          ? (json['debug'] as Map).cast<String, dynamic>()
          : null;

      return ChatApiResponse(
        apiVersion: _asString(json['apiVersion']),
        assistantText: assistantText,
        proposedActions: actions,
        entities: entities,
        warnings: warnings,
        debug: debug,
        traceId: traceId,
      );
    } catch (e) {
      if (e is ApiParseException) {
        throw ApiParseException(
          traceId: e.traceId ?? traceId,
          message: e.message ?? e.toString(),
        );
      }
      throw ApiParseException(
        traceId: traceId,
        message: 'Failed to parse ChatApiResponse: $e',
      );
    }
  }
}

class ProposedActionDto {
  ProposedActionDto({
    required this.id,
    required this.type,
    required this.status,
    required this.payload,
    this.title,
    this.summary,
    this.confidence,
  });

  final String id;
  final String type;
  final String status;
  final Map<String, dynamic> payload;
  final String? title;
  final String? summary;
  final double? confidence;

  factory ProposedActionDto.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final id = _asString(json['id']);
    final type = _asString(json['type']) ?? _asString(json['kind']) ?? 'unknown';
    final status = _asString(json['status']) ?? 'proposed';
    final payload = (json['payload'] is Map)
        ? (json['payload'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return ProposedActionDto(
      id: (id == null || id.isEmpty) ? fallbackId : id,
      type: type,
      status: status,
      payload: payload,
      title: _asString(json['title']),
      summary: _asString(json['summary']),
      confidence: _asConfidence(json['confidence']),
    );
  }
}

class ApplyApiResponse {
  ApplyApiResponse({
    required this.appliedActionIds,
    this.failedActionIds,
    this.changes,
    this.message,
    this.apiVersion,
    this.traceId,
  });

  final List<String> appliedActionIds;
  final List<String>? failedActionIds;
  final List<ChangeDto>? changes;
  final String? message;
  final String? apiVersion;
  final String? traceId;

  bool verifiedApplied(String actionId) => appliedActionIds.contains(actionId);

  factory ApplyApiResponse.fromJson(Map<String, dynamic> json) {
    final traceId = _extractTraceId(json);
    try {
      final appliedRaw = _requireList(
        json['appliedActionIds'],
        field: 'appliedActionIds',
      );
      final applied = appliedRaw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      final failed = _parseStringList(json['failedActionIds']);

      final changes = _parseChanges(json['changes']);

      return ApplyApiResponse(
        apiVersion: _asString(json['apiVersion']),
        appliedActionIds: applied,
        failedActionIds: failed,
        changes: changes,
        message: _asString(json['message']),
        traceId: traceId,
      );
    } catch (e) {
      if (e is ApiParseException) {
        throw ApiParseException(
          traceId: e.traceId ?? traceId,
          message: e.message ?? e.toString(),
        );
      }
      throw ApiParseException(
        traceId: traceId,
        message: 'Failed to parse ApplyApiResponse: $e',
      );
    }
  }
}

class ChangeDto {
  ChangeDto({
    required this.podId,
    required this.podName,
    required this.deltaInCents,
    required this.beforeInCents,
    required this.afterInCents,
  });

  final String podId;
  final String podName;
  final int deltaInCents;
  final int beforeInCents;
  final int afterInCents;

  static ChangeDto? tryFromJson(Map<String, dynamic> json) {
    final podId = _asString(json['podId']) ?? _asString(json['pod_id']);
    final podName = _asString(json['podName']) ?? _asString(json['pod_name']);
    final delta = _asInt(json['deltaInCents']) ?? _asInt(json['delta_in_cents']);
    final before =
        _asInt(json['beforeInCents']) ?? _asInt(json['before_in_cents']);
    final after = _asInt(json['afterInCents']) ?? _asInt(json['after_in_cents']);

    if (podId == null ||
        podId.isEmpty ||
        podName == null ||
        podName.isEmpty ||
        delta == null ||
        before == null ||
        after == null) {
      return null;
    }

    return ChangeDto(
      podId: podId,
      podName: podName,
      deltaInCents: delta,
      beforeInCents: before,
      afterInCents: after,
    );
  }
}

String? _extractTraceId(Map<String, dynamic> json) {
  final raw = json['traceId'] ?? json['trace_id'];
  final s = raw?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

String? _asString(dynamic v) => v is String ? v : v?.toString();

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v == null) return null;
  return int.tryParse(v.toString());
}

double? _asConfidence(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim().toLowerCase();
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

List _requireList(dynamic v, {required String field}) {
  if (v is List) return v;
  throw ApiParseException(message: 'Missing/invalid "$field" (expected list).');
}

String _requireNonEmptyString(dynamic v, {required String field}) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  throw ApiParseException(message: 'Missing/invalid "$field" (expected non-empty string).');
}

List<String>? _parseStringList(dynamic v) {
  if (v is! List) return null;
  final out = v
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  return out.isEmpty ? null : out;
}

List<ChangeDto>? _parseChanges(dynamic v) {
  if (v is! List) return null;
  final out = <ChangeDto>[];
  for (final entry in v) {
    if (entry is Map) {
      final dto = ChangeDto.tryFromJson(entry.cast<String, dynamic>());
      if (dto != null) out.add(dto);
    }
  }
  return out.isEmpty ? null : out;
}

List<String>? _parseWarnings(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : [s];
  }
  if (v is List) {
    final out = v
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return out.isEmpty ? null : out;
  }
  return null;
}

