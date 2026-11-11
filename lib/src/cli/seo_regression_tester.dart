import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

/// Represents an audited SEO metadata snapshot for a single page.
class PageSeoSnapshot {
  const PageSeoSnapshot({
    required this.url,
    this.title,
    this.description,
    this.canonical,
    this.robots = 'index, follow',
    this.ogTitle,
    this.ogDescription,
    this.ogImage,
    this.twitterCard,
    this.jsonLdTypes = const [],
    this.missingAltImages = const [],
  });

  final String url;
  final String? title;
  final String? description;
  final String? canonical;
  final String robots;
  final String? ogTitle;
  final String? ogDescription;
  final String? ogImage;
  final String? twitterCard;
  final List<String> jsonLdTypes;
  final List<String> missingAltImages;

  factory PageSeoSnapshot.fromHtml(String url, String html) {
    final doc = html_parser.parse(html);

    final title = doc.querySelector('title')?.text.trim();
    final description = doc
        .querySelector('meta[name="description"]')
        ?.attributes['content']
        ?.trim();
    final canonical =
        doc.querySelector('link[rel="canonical"]')?.attributes['href']?.trim();
    final robots = doc
            .querySelector('meta[name="robots"]')
            ?.attributes['content']
            ?.trim() ??
        'index, follow';
    final ogTitle = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content']
        ?.trim();
    final ogDescription = doc
        .querySelector('meta[property="og:description"]')
        ?.attributes['content']
        ?.trim();
    final ogImage = doc
        .querySelector('meta[property="og:image"]')
        ?.attributes['content']
        ?.trim();
    final twitterCard = doc
        .querySelector('meta[name="twitter:card"]')
        ?.attributes['content']
        ?.trim();

    final jsonLdTypes = <String>[];
    final scripts = doc.querySelectorAll('script[type="application/ld+json"]');
    for (final s in scripts) {
      try {
        final decoded = json.decode(s.text.trim());
        if (decoded is Map && decoded['@type'] != null) {
          jsonLdTypes.add(decoded['@type'].toString());
        }
      } catch (_) {}
    }

    final missingAlt = <String>[];
    final images = doc.querySelectorAll('img');
    for (final img in images) {
      final alt = img.attributes['alt'];
      final src = img.attributes['src'] ?? 'unknown';
      if (alt == null || alt.trim().isEmpty) {
        missingAlt.add(src);
      }
    }

    return PageSeoSnapshot(
      url: url,
      title: title,
      description: description,
      canonical: canonical,
      robots: robots,
      ogTitle: ogTitle,
      ogDescription: ogDescription,
      ogImage: ogImage,
      twitterCard: twitterCard,
      jsonLdTypes: jsonLdTypes,
      missingAltImages: missingAlt,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'description': description,
        'canonical': canonical,
        'robots': robots,
        'ogTitle': ogTitle,
        'ogDescription': ogDescription,
        'ogImage': ogImage,
        'twitterCard': twitterCard,
        'jsonLdTypes': jsonLdTypes,
        'missingAltImages': missingAltImages,
      };

  factory PageSeoSnapshot.fromJson(Map<String, dynamic> json) =>
      PageSeoSnapshot(
        url: json['url'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        canonical: json['canonical'] as String?,
        robots: json['robots'] as String? ?? 'index, follow',
        ogTitle: json['ogTitle'] as String?,
        ogDescription: json['ogDescription'] as String?,
        ogImage: json['ogImage'] as String?,
        twitterCard: json['twitterCard'] as String?,
        jsonLdTypes: List<String>.from(json['jsonLdTypes'] as List? ?? []),
        missingAltImages:
            List<String>.from(json['missingAltImages'] as List? ?? []),
      );
}

/// Discovered regression finding comparing baseline and current SEO output.
class SeoRegressionFinding {
  const SeoRegressionFinding({
    required this.url,
    required this.field,
    required this.severity,
    required this.baselineValue,
    required this.currentValue,
    required this.message,
  });

  final String url;
  final String field;
  final String severity; // 'CRITICAL', 'WARNING', 'INFO'
  final dynamic baselineValue;
  final dynamic currentValue;
  final String message;

  Map<String, dynamic> toJson() => {
        'url': url,
        'field': field,
        'severity': severity,
        'baseline': baselineValue,
        'current': currentValue,
        'message': message,
      };
}

/// Compares builds and live crawls against baselines to catch accidental SEO regressions.
class SeoRegressionTester {
  const SeoRegressionTester();

  /// Compares two snapshot sets and emits all discovered differences.
  List<SeoRegressionFinding> compareSnapshots({
    required Map<String, PageSeoSnapshot> baseline,
    required Map<String, PageSeoSnapshot> current,
  }) {
    final findings = <SeoRegressionFinding>[];

    for (final entry in baseline.entries) {
      final url = entry.key;
      final base = entry.value;
      final curr = current[url];

      if (curr == null) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'route',
            severity: 'CRITICAL',
            baselineValue: url,
            currentValue: null,
            message: 'Page dropped from build or is no longer reachable.',
          ),
        );
        continue;
      }

      // 1. Title Regressions
      if (base.title != curr.title) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'title',
            severity: (curr.title == null || curr.title!.isEmpty)
                ? 'CRITICAL'
                : 'WARNING',
            baselineValue: base.title,
            currentValue: curr.title,
            message:
                'Page title changed from "${base.title}" to "${curr.title}".',
          ),
        );
      }

      // 2. Meta Description Regressions
      if (base.description != curr.description) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'description',
            severity: (curr.description == null || curr.description!.isEmpty)
                ? 'CRITICAL'
                : 'WARNING',
            baselineValue: base.description,
            currentValue: curr.description,
            message: 'Meta description changed.',
          ),
        );
      }

      // 3. Robots Directive Transition (Accidental Noindex)
      if (!base.robots.contains('noindex') && curr.robots.contains('noindex')) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'robots',
            severity: 'CRITICAL',
            baselineValue: base.robots,
            currentValue: curr.robots,
            message: 'Indexable page transitioned to NOINDEX!',
          ),
        );
      }

      // 4. Canonical URL Regressions
      if (base.canonical != curr.canonical) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'canonical',
            severity: 'CRITICAL',
            baselineValue: base.canonical,
            currentValue: curr.canonical,
            message: 'Canonical URL altered or missing.',
          ),
        );
      }

      // 5. Dropped Open Graph Images
      if (base.ogImage != null &&
          (curr.ogImage == null || curr.ogImage!.isEmpty)) {
        findings.add(
          SeoRegressionFinding(
            url: url,
            field: 'og:image',
            severity: 'CRITICAL',
            baselineValue: base.ogImage,
            currentValue: curr.ogImage,
            message: 'Open Graph social preview image was dropped.',
          ),
        );
      }

      // 6. Dropped JSON-LD Schemas
      for (final baseSchema in base.jsonLdTypes) {
        if (!curr.jsonLdTypes.contains(baseSchema)) {
          findings.add(
            SeoRegressionFinding(
              url: url,
              field: 'jsonLd',
              severity: 'CRITICAL',
              baselineValue: baseSchema,
              currentValue: null,
              message: 'JSON-LD schema "$baseSchema" was removed.',
            ),
          );
        }
      }
    }

    return findings;
  }
}
