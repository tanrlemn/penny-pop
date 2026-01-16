import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:penny_pop_app/api/api_errors.dart';
import 'package:penny_pop_app/api/api_models.dart';
import 'package:penny_pop_app/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Duration kChatTimeout = Duration(seconds: 15);
const Duration kApplyTimeout = Duration(seconds: 20);
const int kMaxMessageChars = 500;

String _redactedPreview(String raw, {int maxChars = 20}) {
  final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return '';
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars)}…';
}

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ChatApiResponse> postMessage({
    required String householdId,
    required String messageText,
  }) async {
    final data = await _postJson(
      path: '/api/chat/message',
      timeout: kChatTimeout,
      body: {
        'householdId': householdId,
        'messageText': messageText,
      },
      requestSummary: 'messageLen=${messageText.length} preview="${_redactedPreview(messageText)}"',
    );
    try {
      return ChatApiResponse.fromJson(data);
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint(
        'ChatService parse failed: endpoint=/api/chat/message traceId=$traceId error=$e',
      );
      rethrow;
    }
  }

  Future<ApplyApiResponse> applyActions({
    required String householdId,
    required List<String> actionIds,
  }) async {
    final data = await _postJson(
      path: '/api/actions/apply',
      timeout: kApplyTimeout,
      body: {
        'householdId': householdId,
        'actionIds': actionIds,
      },
      requestSummary: 'actionCount=${actionIds.length}',
    );
    try {
      return ApplyApiResponse.fromJson(data);
    } catch (e) {
      final traceId = (e is ApiException) ? e.traceId : null;
      debugPrint(
        'ChatService parse failed: endpoint=/api/actions/apply traceId=$traceId error=$e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Duration timeout,
    required Map<String, dynamic> body,
    String? requestSummary,
  }) async {
    final baseUrl = Env.backendBaseUrl;
    if (baseUrl.isEmpty) {
      throw Exception('Missing BACKEND_BASE_URL');
    }

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse(baseUrl).resolve(path);
    final stopwatch = Stopwatch()..start();
    late final http.Response resp;
    Object? decodeError;
    Map<String, dynamic>? decodedMap;
    String? traceId;
    try {
      resp = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      debugPrint(
        'ChatService timeout: endpoint=$path elapsedMs=${stopwatch.elapsedMilliseconds} ${requestSummary ?? ''}',
      );
      rethrow;
    }
    stopwatch.stop();

    final responseBytes = resp.bodyBytes.length;
    if (resp.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          decodedMap = map;
          traceId = _extractTraceId(map);
        } else {
          decodedMap = <String, dynamic>{'data': decoded};
        }
      } catch (e) {
        decodeError = e;
      }
    } else {
      decodedMap = <String, dynamic>{};
    }

    debugPrint(
      'ChatService http: endpoint=$path status=${resp.statusCode} elapsedMs=${stopwatch.elapsedMilliseconds} bytes=$responseBytes traceId=$traceId ${requestSummary ?? ''}',
    );

    if (decodeError != null) {
      // If non-2xx, still throw HTTP exception, but include parse info in logs.
      debugPrint(
        'ChatService decode failed: endpoint=$path status=${resp.statusCode} traceId=$traceId error=$decodeError',
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ApiHttpException(
          statusCode: resp.statusCode,
          bodySnippetRedacted: _redactBodySnippet(resp.body),
          traceId: traceId,
          message: 'Request failed',
        );
      }
      throw ApiParseException(
        traceId: traceId,
        message: 'Invalid JSON response',
      );
    }
    final data = decodedMap ?? <String, dynamic>{};

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 429) {
        final retryAfterSeconds = _parseRetryAfterSeconds(resp, data);
        throw ApiRateLimitedException(
          retryAfterSeconds: retryAfterSeconds,
          traceId: traceId,
          message: 'Too many requests',
        );
      }
      throw ApiHttpException(
        statusCode: resp.statusCode,
        bodySnippetRedacted: _redactBodySnippet(resp.body),
        traceId: traceId,
        message: 'Request failed',
      );
    }

    return data;
  }
}

String? _extractTraceId(Map<String, dynamic> data) {
  final raw = data['traceId'] ?? data['trace_id'];
  final s = raw?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

int? _parseRetryAfterSeconds(http.Response resp, Map<String, dynamic> json) {
  final header = resp.headers['retry-after'] ?? resp.headers['Retry-After'];
  final fromHeader = _tryParseRetryAfterHeaderSeconds(header);
  if (fromHeader != null) return fromHeader;

  final raw = json['retryAfterSeconds'] ?? json['retry_after_seconds'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

int? _tryParseRetryAfterHeaderSeconds(String? value) {
  if (value == null) return null;
  final s = value.trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String _redactBodySnippet(String body, {int maxChars = 240}) {
  var normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '';

  // Never leak user message text if a server echoes it back.
  normalized = normalized.replaceAllMapped(
    RegExp(r'"messageText"\s*:\s*"(?:\\.|[^"\\])*"'),
    (_) => '"messageText":"[redacted]"',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'"message_text"\s*:\s*"(?:\\.|[^"\\])*"'),
    (_) => '"message_text":"[redacted]"',
  );

  if (normalized.length <= maxChars) return normalized;
  return '${normalized.substring(0, maxChars)}…';
}
