import 'dart:async';
import 'dart:convert';
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
class CrawlerInspector {
  CrawlerInspector({
    http.Client? client,
    this.ssrfGuard = const SsrfGuard(allowLocalhostInDev: true),
    this.timeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client();

  final http.Client client;
  final SsrfGuard ssrfGuard;
  final Duration timeout;

  /// Inspects [targetUrl] using raw HTTP GET without running JavaScript.
  Future<UrlInspectionReport> inspectUrl(String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    await ssrfGuard.validateUri(uri);

    final request = http.Request('GET', uri)
      ..headers.addAll({
        'User-Agent':
            'MetaMantle-Crawler/0.1.0 (+https://metamantle.alex.runs-on.dev)',
        'Accept': 'text/html,application/xhtml+xml',
      });

    final streamed = await client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);

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
      findings.add('Server returned HTTP error status ${response.statusCode}.');
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
  }
}
