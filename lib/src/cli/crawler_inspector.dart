import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../security/ssrf_guard.dart';

/// Inspection report for an inspected URL.
class UrlInspectionReport {
  UrlInspectionReport({
    required this.url,
    required this.statusCode,
    required this.headers,
    this.title,
    this.description,
    this.canonical,
    this.robots,
    this.openGraph = const {},
    this.twitter = const {},
    this.jsonLd = const [],
    this.language,
    this.hasFlutterBootstrap = false,
    this.findings = const [],
  });

  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final String? title;
  final String? description;
  final String? canonical;
  final String? robots;
  final Map<String, String> openGraph;
  final Map<String, String> twitter;
  final List<Map<String, dynamic>> jsonLd;
  final String? language;
  final bool hasFlutterBootstrap;
  final List<String> findings;

  Map<String, dynamic> toJson() => {
        'url': url,
        'statusCode': statusCode,
        'headers': headers,
        'title': title,
        'description': description,
        'canonical': canonical,
        'robots': robots,
        'openGraph': openGraph,
        'twitter': twitter,
        'jsonLd': jsonLd,
        'language': language,
        'hasFlutterBootstrap': hasFlutterBootstrap,
        'findings': findings,
      };

  String toTerminalSummary() {
    final buf = StringBuffer();
    buf.writeln('=== MetaMantle URL Inspection Report ===');
    buf.writeln('URL:         $url');
    buf.writeln('Status:      $statusCode');
    buf.writeln('Language:    ${language ?? "(not declared)"}');
    buf.writeln('Title:       ${title ?? "(MISSING)"}');
    buf.writeln('Description: ${description ?? "(MISSING)"}');
    buf.writeln('Canonical:   ${canonical ?? "(not declared)"}');
    buf.writeln('Robots:      ${robots ?? "(default: index, follow)"}');
    buf.writeln('OG Title:    ${openGraph["og:title"] ?? "(not declared)"}');
    buf.writeln('OG Image:    ${openGraph["og:image"] ?? "(not declared)"}');
    buf.writeln('JSON-LD:     ${jsonLd.length} schema block(s) detected');
    buf.writeln(
        'Bootstrap:   ${hasFlutterBootstrap ? "Detected (Progressive / Hybrid)" : "Pure HTML (Zero JS)"}');

    if (findings.isNotEmpty) {
      buf.writeln('\nFindings:');
      for (final f in findings) {
        buf.writeln('  - $f');
      }
    } else {
      buf.writeln('\nFindings: All strict metadata requirements satisfied.');
    }

    return buf.toString();
  }
}

/// Tools for crawling, previewing, and inspecting web endpoints.
/// Call [close] when finished if this instance created its own HTTP client.
class CrawlerInspector {
  CrawlerInspector({
    http.Client? client,
    this.ssrfGuard = const SsrfGuard(),
    this.timeout = const Duration(seconds: 10),
    this.totalTimeout = const Duration(seconds: 30),
    this.maxResponseSizeBytes = 2 * 1024 * 1024,
    this.maxRedirects = 5,
  })  : client = client ?? _createPinnedClient(ssrfGuard),
        _ownsClient = client == null {
    if (timeout <= Duration.zero || totalTimeout <= Duration.zero) {
      throw ArgumentError('Crawler timeouts must be positive.');
    }
    if (maxResponseSizeBytes <= 0 || maxRedirects < 0 || maxRedirects > 10) {
      throw ArgumentError('Invalid crawler response or redirect limit.');
    }
  }

  static http.Client _createPinnedClient(SsrfGuard guard) =>
      guard.createPinnedClient(connectionTimeout: const Duration(seconds: 10));

  final http.Client client;
  final SsrfGuard ssrfGuard;
  final Duration timeout;

  /// Maximum wall-clock time for DNS checks, redirects, headers and body.
  final Duration totalTimeout;

  /// Maximum bytes read from a crawler response body (default 2 MiB).
  final int maxResponseSizeBytes;

  /// Maximum number of validated redirects (default five, hard cap ten).
  final int maxRedirects;
  final bool _ownsClient;

  /// Inspects [targetUrl] using raw HTTP GET without running JavaScript.
  Future<UrlInspectionReport> inspectUrl(String targetUrl) async {
    final watch = Stopwatch()..start();
    try {
      final uri = Uri.parse(targetUrl);
      final response = await _fetch(uri, watch);

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final doc = html_parser.parse(html);

      final title = doc.querySelector('title')?.text.trim();
      final description =
          doc.querySelector('meta[name="description"]')?.attributes['content'];
      final canonical =
          doc.querySelector('link[rel="canonical"]')?.attributes['href'];
      final robots =
          doc.querySelector('meta[name="robots"]')?.attributes['content'];
      final lang = doc.querySelector('html')?.attributes['lang'];

      final og = <String, String>{};
      for (final el in doc.querySelectorAll('meta[property^="og:"]')) {
        final prop = el.attributes['property'];
        final content = el.attributes['content'];
        if (prop != null && content != null) og[prop] = content;
      }

      final twitter = <String, String>{};
      for (final el in doc.querySelectorAll('meta[name^="twitter:"]')) {
        final name = el.attributes['name'];
        final content = el.attributes['content'];
        if (name != null && content != null) twitter[name] = content;
      }

      final jsonLdList = <Map<String, dynamic>>[];
      for (final el
          in doc.querySelectorAll('script[type="application/ld+json"]')) {
        try {
          final decoded = json.decode(el.text);
          if (decoded is Map<String, dynamic>) {
            jsonLdList.add(decoded);
          }
        } catch (_) {}
      }

      final hasBootstrap =
          html.contains('flutter_bootstrap.js') || html.contains('flutter.js');

      final findings = <String>[];
      if (title == null || title.isEmpty) {
        findings.add('Missing <title> tag.');
      }
      if (description == null || description.isEmpty) {
        findings.add('Missing <meta name="description"> tag.');
      }
      if (canonical == null || canonical.isEmpty) {
        findings.add('Missing <link rel="canonical"> tag.');
      }
      if (response.statusCode >= 400) {
        findings
            .add('Server returned HTTP error status ${response.statusCode}.');
      }

      return UrlInspectionReport(
        url: targetUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        title: title,
        description: description,
        canonical: canonical,
        robots: robots,
        openGraph: og,
        twitter: twitter,
        jsonLd: jsonLdList,
        language: lang,
        hasFlutterBootstrap: hasBootstrap,
        findings: findings,
      );
    } on TimeoutException {
      if (_ownsClient) client.close();
      rethrow;
    }
  }

  /// Closes the internally created transport. Injected clients remain caller-owned.
  void close() {
    if (_ownsClient) client.close();
  }

  Future<http.Response> _fetch(Uri initial, Stopwatch watch) async {
    var uri = initial;
    final visited = <String>{};
    for (var redirects = 0;; redirects++) {
      _ensureBudget(watch);
      await ssrfGuard.validateUri(uri).timeout(_remaining(watch));
      final key = uri.normalizePath().toString();
      if (!visited.add(key)) {
        throw const CrawlerException('Redirect loop detected.');
      }
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll({
          'User-Agent': 'MetaMantle-Crawler/0.1.0',
          'Accept': 'text/html,application/xhtml+xml',
        });
      final streamed = await client.send(request).timeout(_hopBudget(watch));
      final location = streamed.headers['location'];
      if (_isRedirect(streamed.statusCode) && location != null) {
        if (redirects >= maxRedirects) {
          await streamed.stream.listen(null).cancel();
          throw CrawlerException(
              'Crawler exceeded maximum of $maxRedirects redirects.');
        }
        final Uri next;
        try {
          next = uri.resolve(location.trim());
        } on FormatException {
          await streamed.stream.listen(null).cancel();
          throw const CrawlerException('Malformed redirect destination.');
        }
        await ssrfGuard.validateUri(next).timeout(_remaining(watch));
        if (uri.scheme == 'https' && next.scheme == 'http') {
          await streamed.stream.listen(null).cancel();
          throw const CrawlerException('HTTPS to HTTP redirects are rejected.');
        }
        // Resolve and validate on the next loop before making a request.
        await streamed.stream.listen(null).cancel();
        uri = next;
        continue;
      }
      if (_isRedirect(streamed.statusCode)) {
        await streamed.stream.listen(null).cancel();
        throw const CrawlerException('Redirect response is missing Location.');
      }
      if (streamed.contentLength != null &&
          streamed.contentLength! > maxResponseSizeBytes) {
        await streamed.stream.listen(null).cancel();
        throw CrawlerResponseTooLargeException(maxResponseSizeBytes);
      }
      final bytes = BytesBuilder(copy: false);
      var length = 0;
      try {
        await for (final chunk in streamed.stream.timeout(_hopBudget(watch))) {
          _ensureBudget(watch);
          length += chunk.length;
          if (length > maxResponseSizeBytes) {
            throw CrawlerResponseTooLargeException(maxResponseSizeBytes);
          }
          bytes.add(chunk);
        }
      } on TimeoutException {
        if (_ownsClient) client.close();
        rethrow;
      }
      return http.Response.bytes(bytes.takeBytes(), streamed.statusCode,
          headers: streamed.headers,
          request: streamed.request,
          reasonPhrase: streamed.reasonPhrase);
    }
  }

  bool _isRedirect(int code) =>
      code == 301 || code == 302 || code == 303 || code == 307 || code == 308;
  Duration _remaining(Stopwatch watch) {
    final value = totalTimeout - watch.elapsed;
    if (value <= Duration.zero) {
      throw TimeoutException('Crawler total time budget exceeded.');
    }
    return value;
  }

  Duration _hopBudget(Stopwatch watch) {
    final remaining = _remaining(watch);
    return remaining < timeout ? remaining : timeout;
  }

  void _ensureBudget(Stopwatch watch) {
    _remaining(watch);
  }
}

/// Base class for safe crawler failures.
class CrawlerException implements Exception {
  const CrawlerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CrawlerResponseTooLargeException extends CrawlerException {
  const CrawlerResponseTooLargeException(int limit)
      : super('Crawler response exceeded the $limit byte limit.');
}
