class ApiException implements Exception {
  ApiException({this.traceId, this.message});

  final String? traceId;
  final String? message;

  @override
  String toString() {
    final base = message ?? runtimeType.toString();
    return traceId == null ? base : '$base (traceId=$traceId)';
  }
}

class ApiParseException extends ApiException {
  ApiParseException({
    super.traceId,
    super.message,
  });
}

class ApiHttpException extends ApiException {
  ApiHttpException({
    required this.statusCode,
    required this.bodySnippetRedacted,
    super.traceId,
    super.message,
  });

  final int statusCode;
  final String bodySnippetRedacted;

  @override
  String toString() {
    final base = message ?? 'HTTP $statusCode';
    final snippet = bodySnippetRedacted.isEmpty ? '' : ' body="$bodySnippetRedacted"';
    final t = traceId == null ? '' : ' traceId=$traceId';
    return '$base$snippet$t';
  }
}

class ApiRateLimitedException extends ApiException {
  ApiRateLimitedException({
    this.retryAfterSeconds,
    super.traceId,
    super.message,
  });

  final int? retryAfterSeconds;

  @override
  String toString() {
    final base = message ?? 'Rate limited';
    final retry = retryAfterSeconds == null ? '' : ' retryAfter=${retryAfterSeconds}s';
    final t = traceId == null ? '' : ' traceId=$traceId';
    return '$base$retry$t';
  }
}

