import '../models/metadata.dart';

/// Validation finding for multilingual SEO and hreflang links.
class HreflangFinding {
  const HreflangFinding({
    required this.routePath,
    required this.message,
    this.isError = false,
  });

  final String routePath;
  final String message;
  final bool isError;
}

/// Validates multilingual hreflang consistency and reciprocal links across routes.
class HreflangValidator {
  const HreflangValidator();

  /// Validates a mapping of canonical route URLs to their declared alternate URLs.
  ///
  /// Checks:
  /// - Reciprocal alternate link consistency (If URL A links to URL B for 'es', URL B must link to URL A for 'en').
  /// - `x-default` presence when multiple regional variants exist.
  /// - Valid language and regional tag formatting (ISO 639-1 / BCP 47).
  List<HreflangFinding> validate(
    Map<String, List<AlternateUrl>> routeAlternates,
  ) {
    final findings = <HreflangFinding>[];

    for (final entry in routeAlternates.entries) {
      final sourceUrl = entry.key;
      final alternates = entry.value;

      if (alternates.isEmpty) continue;

      // Check language tag validity
      var hasXDefault = false;
      for (final alt in alternates) {
        if (alt.language == 'x-default') {
          hasXDefault = true;
          continue;
        }

        if (!_isValidLanguageTag(alt.language)) {
          findings.add(
            HreflangFinding(
              routePath: sourceUrl,
              message:
                  'Malformed hreflang language tag: "${alt.language}". Expected BCP 47 format (e.g. "en", "en-US", "es-ES").',
              isError: true,
            ),
          );
        }

        // Reciprocal link check
        final targetAlternates = routeAlternates[alt.url];
        if (targetAlternates == null) {
          findings.add(
            HreflangFinding(
              routePath: sourceUrl,
              message:
                  'Target alternate URL "${alt.url}" is not configured in the route alternates catalog.',
              isError: false,
            ),
          );
          continue;
        }

        final reciprocal = targetAlternates.any((t) => t.url == sourceUrl);
        if (!reciprocal) {
          findings.add(
            HreflangFinding(
              routePath: sourceUrl,
              message:
                  'Missing reciprocal hreflang return link: "$sourceUrl" links to "${alt.url}" as alternate, but "${alt.url}" does not link back to "$sourceUrl".',
              isError: true,
            ),
          );
        }
      }

      if (alternates.length >= 3 && !hasXDefault) {
        findings.add(
          HreflangFinding(
            routePath: sourceUrl,
            message:
                'Route has multiple language variants (${alternates.length}) but is missing an "x-default" fallback directive.',
            isError: false,
          ),
        );
      }
    }

    return findings;
  }

  bool _isValidLanguageTag(String tag) {
    // Basic BCP 47 regex: 2-3 letter language, optional script, optional 2-letter region or 3-digit UN M.49
    final regex = RegExp(
      r'^[a-zA-Z]{2,3}(-[a-zA-Z]{4})?(-([a-zA-Z]{2}|\d{3}))?$',
    );
    return regex.hasMatch(tag);
  }
}
