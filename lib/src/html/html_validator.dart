import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import '../core/head_injector.dart';

/// Severity of an HTML validation issue.
enum HtmlValidationSeverity { error, warning }

/// Status of optional external HTML5 standards conformance validation (e.g. Nu HTML Checker / W3C v.Nu).
enum ExternalStandardsValidationStatus { passed, failed, skipped, unavailable }

/// Result of an external HTML5 standards conformance audit.
class ExternalStandardsValidationResult {
  const ExternalStandardsValidationResult({
    required this.status,
    required this.validatorName,
    this.messages = const [],
    this.reason,
  });

  final ExternalStandardsValidationStatus status;
  final String validatorName;
  final List<String> messages;
  final String? reason;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'validatorName': validatorName,
    'messages': messages,
    if (reason != null) 'reason': reason,
  };
}

/// A specific issue found during HTML validation.
class HtmlValidationIssue {
  const HtmlValidationIssue({
    required this.message,
    required this.severity,
    this.rule,
    this.line,
  });

  final String message;
  final HtmlValidationSeverity severity;
  final String? rule;
  final int? line;

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $message${rule != null ? ' ($rule)' : ''}';
}

/// Report for a single HTML document validation.
class HtmlDocumentValidationReport {
  const HtmlDocumentValidationReport({
    required this.filePath,
    required this.issues,
    required this.checkedRulesCount,
    this.standardsResult,
  });

  final String filePath;
  final List<HtmlValidationIssue> issues;
  final int checkedRulesCount;
  final ExternalStandardsValidationResult? standardsResult;

  bool get isValid =>
      issues.every((i) => i.severity != HtmlValidationSeverity.error) &&
      (standardsResult?.status != ExternalStandardsValidationStatus.failed);

  bool get hasWarnings =>
      issues.any((i) => i.severity == HtmlValidationSeverity.warning);
  List<HtmlValidationIssue> get errors =>
      issues.where((i) => i.severity == HtmlValidationSeverity.error).toList();
  List<HtmlValidationIssue> get warnings => issues
      .where((i) => i.severity == HtmlValidationSeverity.warning)
      .toList();

  HtmlDocumentValidationReport copyWith({
    List<HtmlValidationIssue>? issues,
    int? checkedRulesCount,
    ExternalStandardsValidationResult? standardsResult,
  }) => HtmlDocumentValidationReport(
    filePath: filePath,
    issues: issues ?? this.issues,
    checkedRulesCount: checkedRulesCount ?? this.checkedRulesCount,
    standardsResult: standardsResult ?? this.standardsResult,
  );

  Map<String, Object?> toJson() => {
    'filePath': filePath,
    'isValid': isValid,
    'errorCount': errors.length,
    'warningCount': warnings.length,
    'issues': issues
        .map(
          (i) => {
            'severity': i.severity.name,
            'message': i.message,
            'rule': i.rule,
            if (i.line != null) 'line': i.line,
          },
        )
        .toList(),
    if (standardsResult != null) 'standardsResult': standardsResult!.toJson(),
  };
}

/// Comprehensive HTML5 quality auditor and validator.
class HtmlValidator {
  const HtmlValidator();

  /// Validates an HTML document string against HTML5 conformance and SEO quality rules.
  HtmlDocumentValidationReport validateHtml(
    String htmlContent, {
    String filePath = 'index.html',
    Directory? baseDir,
  }) {
    final issues = <HtmlValidationIssue>[];
    var rulesCount = 0;

    // 1. Encoding check (Mojibake & Replacement Character)
    rulesCount++;
    if (htmlContent.contains('\uFFFD')) {
      issues.add(
        const HtmlValidationIssue(
          message: 'Document contains U+FFFD Unicode replacement characters (decoding corruption).',
          severity: HtmlValidationSeverity.error,
          rule: 'utf8-encoding',
        ),
      );
    }
    // Check known Windows-1252 to UTF-8 mojibake signatures
    final mojibakeSignatures = [
      'â†’',
      'â€œ',
      'â€',
      'â€™',
      'Ã©',
      'Ã±',
      'Ã¼',
      'Â©',
      'â„¢',
    ];
    for (final sig in mojibakeSignatures) {
      if (htmlContent.contains(sig)) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Detected mojibake encoding artifact ("$sig"). Document has corrupted UTF-8 bytes.',
            severity: HtmlValidationSeverity.error,
            rule: 'utf8-encoding',
          ),
        );
        break;
      }
    }

    // 2. Pre-parse source-level structural checks (to catch errors normalized away by DOM parser)
    rulesCount += 4;
    final doctypeMatches = RegExp(
      r'<!DOCTYPE\b',
      caseSensitive: false,
    ).allMatches(htmlContent);
    if (doctypeMatches.length > 1) {
      issues.add(
        HtmlValidationIssue(
          message:
              'Malformed document: found ${doctypeMatches.length} <!DOCTYPE> declarations in source.',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-doctype-duplicate',
        ),
      );
    }

    final rawHtmlTags = RegExp(
      r'<html\b',
      caseSensitive: false,
    ).allMatches(htmlContent);
    if (rawHtmlTags.length > 1) {
      issues.add(
        HtmlValidationIssue(
          message:
              'Malformed document: found ${rawHtmlTags.length} <html> opening tags in source (multiple root elements).',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-html-duplicate',
        ),
      );
    }

    final rawHeadTags = RegExp(
      r'<head\b',
      caseSensitive: false,
    ).allMatches(htmlContent);
    if (rawHeadTags.length > 1) {
      issues.add(
        HtmlValidationIssue(
          message:
              'Malformed document: found ${rawHeadTags.length} <head> opening tags in source (duplicate <head> structure).',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-head-duplicate',
        ),
      );
    }

    final rawBodyTags = RegExp(
      r'<body\b',
      caseSensitive: false,
    ).allMatches(htmlContent);
    if (rawBodyTags.length > 1) {
      issues.add(
        HtmlValidationIssue(
          message:
              'Malformed document: found ${rawBodyTags.length} <body> opening tags in source (duplicate <body> structure).',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-body-duplicate',
        ),
      );
    }

    final doc = html_parser.parse(htmlContent);

    // 2. Document Structure (single html, head, body)
    rulesCount += 4;
    final htmlElements = doc.querySelectorAll('html');
    if (htmlElements.isEmpty) {
      issues.add(
        const HtmlValidationIssue(
          message: 'Missing root <html> element.',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-html',
        ),
      );
    } else {
      final rootHtml = htmlElements.first;
      final lang = rootHtml.attributes['lang']?.trim();
      if (lang == null || lang.isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message:
                'Missing or empty "lang" attribute on root <html> element.',
            severity: HtmlValidationSeverity.error,
            rule: 'html-lang',
          ),
        );
      }
    }

    final headElements = doc.querySelectorAll('head');
    if (headElements.isEmpty) {
      issues.add(
        const HtmlValidationIssue(
          message: 'Missing <head> element.',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-head',
        ),
      );
    }

    final bodyElements = doc.querySelectorAll('body');
    if (bodyElements.isEmpty) {
      issues.add(
        const HtmlValidationIssue(
          message: 'Missing <body> element.',
          severity: HtmlValidationSeverity.error,
          rule: 'structure-body',
        ),
      );
    }

    // 3. Misplaced or nested HTML/body/head tags
    rulesCount += 5;
    if (headElements.isNotEmpty) {
      final head = headElements.first;

      // Never insert html or body inside head
      final nestedHtmls = head.querySelectorAll('html');
      if (nestedHtmls.isNotEmpty) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Malformed document: found ${nestedHtmls.length} <html> element(s) inside <head>.',
            severity: HtmlValidationSeverity.error,
            rule: 'misplaced-element',
          ),
        );
      }

      final nestedBodies = head.querySelectorAll('body');
      if (nestedBodies.isNotEmpty) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Malformed document: found ${nestedBodies.length} <body> element(s) inside <head>.',
            severity: HtmlValidationSeverity.error,
            rule: 'misplaced-element',
          ),
        );
      }

      // Check character encoding declaration
      final hasCharset =
          head.querySelectorAll('meta[charset]').isNotEmpty ||
          head
              .querySelectorAll('meta')
              .any(
                (m) =>
                    m.attributes['http-equiv']?.toLowerCase() == 'content-type',
              );
      if (!hasCharset) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Missing character encoding declaration (<meta charset="UTF-8">) in <head>.',
            severity: HtmlValidationSeverity.error,
            rule: 'charset-meta',
          ),
        );
      }
    }

    if (bodyElements.isNotEmpty) {
      final body = bodyElements.first;
      final nestedHtmls = body.querySelectorAll('html');
      if (nestedHtmls.isNotEmpty) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Malformed document: found ${nestedHtmls.length} <html> element(s) inside <body>.',
            severity: HtmlValidationSeverity.error,
            rule: 'misplaced-element',
          ),
        );
      }

      final nestedHeads = body.querySelectorAll('head');
      if (nestedHeads.isNotEmpty) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Malformed document: found ${nestedHeads.length} <head> element(s) inside <body>.',
            severity: HtmlValidationSeverity.error,
            rule: 'misplaced-element',
          ),
        );
      }

      // Misplaced title or base in body
      final misplacedHeadTags = body.querySelectorAll('title, base');
      if (misplacedHeadTags.isNotEmpty) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Misplaced <${misplacedHeadTags.first.localName}> element found inside <body>.',
            severity: HtmlValidationSeverity.error,
            rule: 'misplaced-element',
          ),
        );
      }
    }

    // 4. Metadata Uniqueness & Validation
    rulesCount += 6;
    if (headElements.isNotEmpty) {
      final head = headElements.first;

      // Title
      final titles = head.querySelectorAll('title');
      if (titles.isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Missing <title> element in <head>.',
            severity: HtmlValidationSeverity.error,
            rule: 'title-missing',
          ),
        );
      } else if (titles.length > 1) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Duplicate <title> elements detected (${titles.length} elements).',
            severity: HtmlValidationSeverity.error,
            rule: 'title-duplicate',
          ),
        );
      } else if (titles.first.text.trim().isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Empty <title> element.',
            severity: HtmlValidationSeverity.warning,
            rule: 'title-empty',
          ),
        );
      }

      // Meta Description
      final descriptions = head
          .querySelectorAll('meta')
          .where((m) => m.attributes['name']?.toLowerCase() == 'description')
          .toList();
      if (descriptions.length > 1) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Duplicate <meta name="description"> elements detected (${descriptions.length} elements).',
            severity: HtmlValidationSeverity.error,
            rule: 'description-duplicate',
          ),
        );
      } else if (descriptions.isNotEmpty &&
          (descriptions.first.attributes['content']?.trim().isEmpty ?? true)) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Empty content in <meta name="description">.',
            severity: HtmlValidationSeverity.warning,
            rule: 'description-empty',
          ),
        );
      }

      // Canonical Link
      final canonicals = head
          .querySelectorAll('link')
          .where((l) => l.attributes['rel']?.toLowerCase() == 'canonical')
          .toList();
      if (canonicals.length > 1) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Duplicate <link rel="canonical"> elements detected (${canonicals.length} elements).',
            severity: HtmlValidationSeverity.error,
            rule: 'canonical-duplicate',
          ),
        );
      } else if (canonicals.isNotEmpty) {
        final href = canonicals.first.attributes['href']?.trim();
        if (href == null || href.isEmpty) {
          issues.add(
            const HtmlValidationIssue(
              message: 'Empty href in <link rel="canonical">.',
              severity: HtmlValidationSeverity.error,
              rule: 'canonical-empty',
            ),
          );
        } else if (!href.startsWith('http://') &&
            !href.startsWith('https://') &&
            !href.startsWith('/')) {
          issues.add(
            HtmlValidationIssue(
              message:
                  'Invalid canonical URL format: "$href". Must start with http://, https://, or /.',
              severity: HtmlValidationSeverity.error,
              rule: 'canonical-format',
            ),
          );
        }
      }

      // Robots
      final robots = head
          .querySelectorAll('meta')
          .where((m) => m.attributes['name']?.toLowerCase() == 'robots')
          .toList();
      if (robots.length > 1) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Duplicate <meta name="robots"> elements detected (${robots.length} elements).',
            severity: HtmlValidationSeverity.error,
            rule: 'robots-duplicate',
          ),
        );
      }

      // Open Graph duplicates
      final ogProperties = <String>{};
      for (final og in head.querySelectorAll('meta')) {
        final prop = og.attributes['property']?.toLowerCase();
        if (prop != null && prop.startsWith('og:')) {
          // Some og properties like og:image:alt or multiple og:image are allowed,
          // but primary tags like og:title, og:description, og:url, og:site_name, og:type must be unique.
          final primaryProps = {
            'og:title',
            'og:description',
            'og:url',
            'og:site_name',
            'og:type',
          };
          if (primaryProps.contains(prop) && !ogProperties.add(prop)) {
            issues.add(
              HtmlValidationIssue(
                message: 'Duplicate Open Graph property detected: "$prop".',
                severity: HtmlValidationSeverity.error,
                rule: 'og-duplicate',
              ),
            );
          }
        }
      }

      // Twitter duplicates
      final twitterNames = <String>{};
      for (final tw in head.querySelectorAll('meta')) {
        final name = tw.attributes['name']?.toLowerCase();
        if (name != null && name.startsWith('twitter:')) {
          if (!twitterNames.add(name)) {
            issues.add(
              HtmlValidationIssue(
                message: 'Duplicate Twitter card metadata detected: "$name".',
                severity: HtmlValidationSeverity.error,
                rule: 'twitter-duplicate',
              ),
            );
          }
        }
      }
    }

    // 5. Structured Data (JSON-LD) Validation
    rulesCount++;
    final jsonLdScripts = doc.querySelectorAll(
      'script[type="application/ld+json"]',
    );
    final seenJsonLdSignatures = <String>{};
    for (final script in jsonLdScripts) {
      final jsonText = script.text.trim();
      if (jsonText.isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Empty <script type="application/ld+json"> tag.',
            severity: HtmlValidationSeverity.error,
            rule: 'jsonld-empty',
          ),
        );
        continue;
      }
      try {
        final decoded = json.decode(jsonText);
        if (decoded is Map) {
          if (!decoded.containsKey('@context')) {
            issues.add(
              const HtmlValidationIssue(
                message: 'JSON-LD object missing "@context" property.',
                severity: HtmlValidationSeverity.error,
                rule: 'jsonld-context',
              ),
            );
          }
          if (!decoded.containsKey('@type')) {
            issues.add(
              const HtmlValidationIssue(
                message: 'JSON-LD object missing "@type" property.',
                severity: HtmlValidationSeverity.error,
                rule: 'jsonld-type',
              ),
            );
          }
          final keys = HeadInjector.computeJsonLdEntityKeys(decoded);
          for (final key in keys) {
            if (!seenJsonLdSignatures.add(key)) {
              issues.add(
                HtmlValidationIssue(
                  message:
                      'Duplicate JSON-LD structured data block for entity "$key".',
                  severity: HtmlValidationSeverity.warning,
                  rule: 'jsonld-duplicate',
                ),
              );
              break;
            }
          }
        } else if (decoded is List) {
          final keys = HeadInjector.computeJsonLdEntityKeys(decoded);
          for (final key in keys) {
            if (!seenJsonLdSignatures.add(key)) {
              issues.add(
                HtmlValidationIssue(
                  message:
                      'Duplicate JSON-LD structured data block for entity "$key".',
                  severity: HtmlValidationSeverity.warning,
                  rule: 'jsonld-duplicate',
                ),
              );
              break;
            }
          }
        } else {
          issues.add(
            const HtmlValidationIssue(
              message: 'JSON-LD root must be a JSON object or array.',
              severity: HtmlValidationSeverity.error,
              rule: 'jsonld-structure',
            ),
          );
        }
      } on FormatException catch (e) {
        issues.add(
          HtmlValidationIssue(
            message: 'Malformed JSON-LD syntax: ${e.message}',
            severity: HtmlValidationSeverity.error,
            rule: 'jsonld-syntax',
          ),
        );
      }
    }

    // 6. Responsive Image Quality & Accessibility
    rulesCount += 2;
    final images = doc.querySelectorAll('img');
    for (final img in images) {
      final src = img.attributes['src']?.trim();
      if (src == null || src.isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Image element has empty or missing "src" attribute.',
            severity: HtmlValidationSeverity.error,
            rule: 'img-src',
          ),
        );
      }
      if (!img.attributes.containsKey('alt')) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Missing "alt" attribute on <img> element (src: "${src ?? 'unknown'}").',
            severity: HtmlValidationSeverity.warning,
            rule: 'img-alt',
          ),
        );
      }

      // Check fixed dimensions vs responsiveness
      final style = img.attributes['style'] ?? '';
      final hasFixedWidthPx = RegExp(r'\bwidth:\s*\d+(\.\d+)?px\b')
          .hasMatch(style);
      final hasMaxWidth =
          style.contains('max-width: 100%') || style.contains('max-width:100%');
      if (hasFixedWidthPx && !hasMaxWidth) {
        issues.add(
          HtmlValidationIssue(
            message:
                'Image has fixed pixel width without "max-width: 100%" (risks viewport overflow on mobile): "${src ?? 'unknown'}".',
            severity: HtmlValidationSeverity.warning,
            rule: 'img-responsive',
          ),
        );
      }
    }

    // 7. Navigation Semantics
    rulesCount += 2;
    // Check for buttons with role="tab" used outside tablist
    final tabButtons = doc.querySelectorAll('button[role="tab"]');
    for (final btn in tabButtons) {
      final parentTabList =
          btn.parent?.attributes['role'] == 'tablist' ||
          btn.parent?.parent?.attributes['role'] == 'tablist';
      if (!parentTabList) {
        issues.add(
          HtmlValidationIssue(
            message: 'Invalid navigation semantics: <button role="tab"> used outside of an element with role="tablist" (navigation items must be anchor <a> links).',
            severity: HtmlValidationSeverity.error,
            rule: 'nav-semantics',
          ),
        );
      }
    }

    // Check ordinary buttons for invalid selection attributes
    final allButtons = doc.querySelectorAll('button');
    for (final btn in allButtons) {
      if (btn.attributes.containsKey('aria-selected') &&
          btn.attributes['role'] != 'tab') {
        issues.add(
          const HtmlValidationIssue(
            message: 'Invalid ARIA attribute: <button> must not have "aria-selected" unless role="tab". For toggle buttons, use "aria-pressed".',
            severity: HtmlValidationSeverity.error,
            rule: 'button-aria-selected',
          ),
        );
      }
    }

    // Anchor links validation
    final anchors = doc.querySelectorAll('a');
    for (final a in anchors) {
      final href = a.attributes['href']?.trim();
      if (a.attributes.containsKey('aria-selected') &&
          a.attributes['role'] != 'tab') {
        issues.add(
          HtmlValidationIssue(
            message:
                'Invalid navigation ARIA: anchor <a> with href "${href ?? ''}" must not use "aria-selected" (use "aria-current=\\"page\\"" for active page links).',
            severity: HtmlValidationSeverity.error,
            rule: 'nav-aria-selected',
          ),
        );
      }
      if (href == null || href.isEmpty) {
        issues.add(
          const HtmlValidationIssue(
            message: 'Anchor tag <a> has missing or empty "href" attribute.',
            severity: HtmlValidationSeverity.error,
            rule: 'anchor-href',
          ),
        );
      } else if (baseDir != null &&
          href.startsWith('/') &&
          !href.startsWith('//')) {
        // Internal route link verification
        final cleanPath = href.split('?').first.split('#').first;
        if (cleanPath.isNotEmpty && cleanPath != '/') {
          final relPath = cleanPath.substring(1);
          final candidates = [
            File('${baseDir.path}/$relPath/index.html'),
            File('${baseDir.path}/$relPath.html'),
            File('${baseDir.path}/$relPath'),
          ];
          final exists = candidates.any((f) => f.existsSync());
          if (!exists) {
            issues.add(
              HtmlValidationIssue(
                message:
                    'Broken internal route link: href "$href" does not resolve to an existing route file.',
                severity: HtmlValidationSeverity.error,
                rule: 'link-internal',
              ),
            );
          }
        }
      }
    }

    // 8. Broken Local Asset References
    if (baseDir != null) {
      rulesCount += 2;
      // Local scripts
      for (final script in doc.querySelectorAll('script[src]')) {
        final src = script.attributes['src']?.trim() ?? '';
        if (src.isNotEmpty &&
            !src.startsWith('http://') &&
            !src.startsWith('https://') &&
            !src.startsWith('//') &&
            !src.startsWith('data:')) {
          final cleanSrc = src.split('?').first.split('#').first;
          final assetFile = File(
            cleanSrc.startsWith('/')
                ? '${baseDir.path}$cleanSrc'
                : '${baseDir.path}/$cleanSrc',
          );
          if (!assetFile.existsSync()) {
            issues.add(
              HtmlValidationIssue(
                message:
                    'Broken local asset reference: script "$src" does not exist in build output.',
                severity: HtmlValidationSeverity.error,
                rule: 'asset-script',
              ),
            );
          }
        }
      }

      // Local stylesheets
      for (final link in doc.querySelectorAll('link[rel="stylesheet"][href]')) {
        final href = link.attributes['href']?.trim() ?? '';
        if (href.isNotEmpty &&
            !href.startsWith('http://') &&
            !href.startsWith('https://') &&
            !href.startsWith('//')) {
          final cleanHref = href.split('?').first.split('#').first;
          final assetFile = File(
            cleanHref.startsWith('/')
                ? '${baseDir.path}$cleanHref'
                : '${baseDir.path}/$cleanHref',
          );
          if (!assetFile.existsSync()) {
            issues.add(
              HtmlValidationIssue(
                message:
                    'Broken local asset reference: stylesheet "$href" does not exist in build output.',
                severity: HtmlValidationSeverity.error,
                rule: 'asset-stylesheet',
              ),
            );
          }
        }
      }

      // Local image assets
      for (final img in images) {
        final src = img.attributes['src']?.trim() ?? '';
        if (src.isNotEmpty &&
            !src.startsWith('http://') &&
            !src.startsWith('https://') &&
            !src.startsWith('//') &&
            !src.startsWith('data:')) {
          final cleanSrc = src.split('?').first.split('#').first;
          final assetFile = File(
            cleanSrc.startsWith('/')
                ? '${baseDir.path}$cleanSrc'
                : '${baseDir.path}/$cleanSrc',
          );
          if (!assetFile.existsSync()) {
            issues.add(
              HtmlValidationIssue(
                message:
                    'Broken local image asset: "$src" does not exist in build output.',
                severity: HtmlValidationSeverity.error,
                rule: 'asset-image',
              ),
            );
          }
        }
      }
    }

    return HtmlDocumentValidationReport(
      filePath: filePath,
      issues: issues,
      checkedRulesCount: rulesCount,
    );
  }

  /// Asynchronously validates [htmlContent] against both MetaMantle internal quality rules
  /// and an optional external HTML5 standards conformance validator (e.g. Nu HTML Checker / W3C v.Nu).
  Future<HtmlDocumentValidationReport> validateHtmlWithStandards(
    String htmlContent, {
    String filePath = 'index.html',
    Directory? baseDir,
    bool enableNuChecker = false,
    String? nuCheckerUrl,
  }) async {
    final report = validateHtml(
      htmlContent,
      filePath: filePath,
      baseDir: baseDir,
    );
    if (!enableNuChecker) {
      return report.copyWith(
        standardsResult: const ExternalStandardsValidationResult(
          status: ExternalStandardsValidationStatus.skipped,
          validatorName: 'Nu HTML Checker (W3C v.Nu)',
          reason: 'External standards validation skipped (not requested).',
        ),
      );
    }

    final standardsResult = await queryNuHtmlChecker(
      htmlContent,
      endpointUrl: nuCheckerUrl,
    );

    return report.copyWith(standardsResult: standardsResult);
  }

  /// Sends [htmlContent] to an external Nu HTML Checker instance (W3C v.Nu) for standards validation.
  /// Handles validator availability and network timeouts honestly without falsely reporting passed.
  static Future<ExternalStandardsValidationResult> queryNuHtmlChecker(
    String htmlContent, {
    String? endpointUrl,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final url =
        endpointUrl ??
        Platform.environment['VNU_URL'] ??
        'https://validator.w3.org/nu/?out=json';
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'text/html; charset=utf-8');
      request.headers.set('User-Agent', 'MetaMantle-HtmlValidator/0.2.0');
      request.write(htmlContent);
      final response = await request.close().timeout(timeout);

      if (response.statusCode != 200) {
        return ExternalStandardsValidationResult(
          status: ExternalStandardsValidationStatus.unavailable,
          validatorName: 'Nu HTML Checker ($url)',
          reason: 'Validator returned HTTP status ${response.statusCode}',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = json.decode(responseBody);
      final messages = <String>[];
      var hasErrors = false;

      if (decoded is Map && decoded['messages'] is List) {
        for (final msg in decoded['messages'] as List) {
          if (msg is Map) {
            final type = msg['type']?.toString() ?? 'info';
            final text = msg['message']?.toString() ?? '';
            final line = msg['lastLine']?.toString() ?? '?';
            messages.add('[$type line $line] $text');
            if (type == 'error') {
              hasErrors = true;
            }
          }
        }
      }

      return ExternalStandardsValidationResult(
        status: hasErrors
            ? ExternalStandardsValidationStatus.failed
            : ExternalStandardsValidationStatus.passed,
        validatorName: 'Nu HTML Checker ($url)',
        messages: messages,
      );
    } catch (e) {
      return ExternalStandardsValidationResult(
        status: ExternalStandardsValidationStatus.unavailable,
        validatorName: 'Nu HTML Checker ($url)',
        reason: 'Connection to validator failed or timed out: $e',
      );
    }
  }

  /// Validates all `.html` files in [dir].
  Future<DirectoryValidationReport> validateDirectory(
    Directory dir, {
    bool strict = false,
    bool enableNuChecker = false,
    String? nuCheckerUrl,
  }) async {
    final reports = <HtmlDocumentValidationReport>[];
    if (!await dir.exists()) {
      return DirectoryValidationReport(
        dirPath: dir.path,
        reports: const [],
        directoryExists: false,
      );
    }

    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.html'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final html = await file.readAsString();
      final relPath = file.path.startsWith(dir.path)
          ? file.path.substring(dir.path.length + 1)
          : file.path;

      if (enableNuChecker) {
        final report = await validateHtmlWithStandards(
          html,
          filePath: relPath,
          baseDir: dir,
          enableNuChecker: true,
          nuCheckerUrl: nuCheckerUrl,
        );
        reports.add(report);
      } else {
        final report = validateHtml(html, filePath: relPath, baseDir: dir);
        reports.add(report);
      }
    }

    return DirectoryValidationReport(
      dirPath: dir.path,
      reports: reports,
      directoryExists: true,
      strict: strict,
      enableNuChecker: enableNuChecker,
      nuCheckerUrl: nuCheckerUrl,
    );
  }
}

/// Aggregated report for a directory of HTML documents.
class DirectoryValidationReport {
  const DirectoryValidationReport({
    required this.dirPath,
    required this.reports,
    required this.directoryExists,
    this.strict = false,
    this.enableNuChecker = false,
    this.nuCheckerUrl,
  });

  final String dirPath;
  final List<HtmlDocumentValidationReport> reports;
  final bool directoryExists;
  final bool strict;
  final bool enableNuChecker;
  final String? nuCheckerUrl;

  int get totalFiles => reports.length;
  int get totalErrors => reports.fold(0, (sum, r) => sum + r.errors.length);
  int get totalWarnings => reports.fold(0, (sum, r) => sum + r.warnings.length);

  bool get isSuccessful {
    if (!directoryExists) return false;
    if (totalErrors > 0) return false;
    if (strict && totalWarnings > 0) return false;
    if (reports.any(
      (r) =>
          r.standardsResult?.status == ExternalStandardsValidationStatus.failed,
    )) {
      return false;
    }
    return true;
  }

  String toTerminalSummary() {
    final buf = StringBuffer();
    buf.writeln('=== MetaMantle HTML5 Conformance & Quality Report ===');
    buf.writeln('Directory: $dirPath');
    buf.writeln('Total HTML Files: $totalFiles\n');

    for (final report in reports) {
      if (report.isValid && !report.hasWarnings) {
        buf.writeln('  [PASS] ${report.filePath}');
      } else {
        final status = !report.isValid ? 'FAIL' : 'WARN';
        buf.writeln(
          '  [$status] ${report.filePath} (${report.errors.length} error(s), ${report.warnings.length} warning(s))',
        );
        for (final issue in report.issues) {
          buf.writeln('    - ${issue.toString()}');
        }
        if (report.standardsResult != null) {
          final s = report.standardsResult!;
          buf.writeln(
            '    - [STANDARDS: ${s.status.name.toUpperCase()}] ${s.validatorName}${s.reason != null ? ' (${s.reason})' : ''}',
          );
          for (final msg in s.messages) {
            buf.writeln('        * $msg');
          }
        }
      }
    }

    buf.writeln(
      '\nSummary: $totalFiles file(s) checked, $totalErrors error(s), $totalWarnings warning(s).',
    );

    if (enableNuChecker) {
      final passedCount = reports
          .where(
            (r) =>
                r.standardsResult?.status ==
                ExternalStandardsValidationStatus.passed,
          )
          .length;
      final failedCount = reports
          .where(
            (r) =>
                r.standardsResult?.status ==
                ExternalStandardsValidationStatus.failed,
          )
          .length;
      final unavailCount = reports
          .where(
            (r) =>
                r.standardsResult?.status ==
                ExternalStandardsValidationStatus.unavailable,
          )
          .length;
      buf.writeln(
        'External Standards (Nu HTML Checker): $passedCount passed, $failedCount failed, $unavailCount unavailable.',
      );
    } else {
      buf.writeln(
        'External Standards (Nu HTML Checker): SKIPPED (use --nu-validate to enable)',
      );
    }

    if (!isSuccessful) {
      buf.writeln('STATUS: VALIDATION FAILED (strict: $strict)');
    } else {
      buf.writeln('STATUS: VALIDATION PASSED');
    }
    return buf.toString();
  }
}
