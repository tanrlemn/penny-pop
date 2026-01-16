import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:penny_pop_app/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessageResponseBody {
  ChatMessageResponseBody({required this.data});

  final Map<String, dynamic> data;

  factory ChatMessageResponseBody.fromJson(Map<String, dynamic> json) {
    return ChatMessageResponseBody(data: json);
  }

  @override
  String toString() => jsonEncode(data);
}

class ApplyActionsResponseBody {
  ApplyActionsResponseBody({required this.data});

  final Map<String, dynamic> data;

  factory ApplyActionsResponseBody.fromJson(Map<String, dynamic> json) {
    return ApplyActionsResponseBody(data: json);
  }

  @override
  String toString() => jsonEncode(data);
}

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ChatMessageResponseBody> postMessage({
    required String householdId,
    required String messageText,
  }) async {
    final data = await _postJson(
      path: '/api/chat/message',
      body: {
        'householdId': householdId,
        'messageText': messageText,
      },
    );
    return ChatMessageResponseBody.fromJson(data);
  }

  Future<ApplyActionsResponseBody> applyActions({
    required String householdId,
    required List<String> actionIds,
  }) async {
    final data = await _postJson(
      path: '/api/actions/apply',
      body: {
        'householdId': householdId,
        'actionIds': actionIds,
      },
    );
    return ApplyActionsResponseBody.fromJson(data);
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
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
    late final http.Response resp;
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
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Request timed out. Try again.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Chat API $path failed (${resp.statusCode}): ${resp.body}',
      );
    }

    if (resp.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{'data': decoded};
  }
}
