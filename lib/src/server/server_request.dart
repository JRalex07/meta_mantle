import 'dart:convert';

/// Framework-agnostic HTTP request representation for MetaMantle SSR.
class ServerRequest {
  ServerRequest({
    required this.method,
    required this.uri,
    Map<String, String>? headers,
    this.clientIp,
    List<int>? bodyBytes,
  })  : headers = headers != null
            ? Map.unmodifiable(
                headers.map((k, v) => MapEntry(k.toLowerCase(), v)))
            : const {},
        bodyBytes = bodyBytes ?? const [];

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? clientIp;
  final List<int> bodyBytes;

  /// Normalized request path (e.g. '/products/basmati-rice/').
  String get path => uri.path.isEmpty ? '/' : uri.path;

  /// Parsed query parameters.
  Map<String, String> get queryParameters => uri.queryParameters;

  /// Retrieves an incoming header by name (case-insensitive).
  String? header(String name) => headers[name.toLowerCase()];

  /// Retrieves the `If-None-Match` header value.
  String? get ifNoneMatch => header('if-none-match');

  /// Retrieves the parsed `If-Modified-Since` header if valid.
  DateTime? get ifModifiedSince {
    final raw = header('if-modified-since');
    if (raw == null) return null;
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Request body decoded as UTF-8 string.
  String get bodyText => utf8.decode(bodyBytes);
}

/// Helper for HTTP date parsing according to RFC 9110.
class HttpDate {
  const HttpDate._();

  static DateTime parse(String dateString) {
    // Standard RFC 1123 format: "Wed, 21 Oct 2026 07:28:00 GMT"
    return DateTime.parse(dateString).toUtc();
  }

  static String format(DateTime date) {
    return date.toUtc().toIso8601String();
  }
}
