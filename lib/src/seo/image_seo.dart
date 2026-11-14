import 'package:html/parser.dart' as html_parser;

/// Severity of an image SEO or performance finding.
enum ImageIssueSeverity { info, warning, error }

/// Represents an individual audit finding for an image.
class ImageFinding {
  const ImageFinding({
    required this.src,
    required this.alt,
    required this.hasAlt,
    required this.hasDimensions,
    required this.hasLazyLoading,
    this.width,
    this.height,
    this.loading,
    this.fetchPriority,
    this.srcset,
    this.pageUrl,
    this.issues = const [],
  });

  final String src;
  final String? alt;
  final bool hasAlt;
  final bool hasDimensions;
  final bool hasLazyLoading;
  final int? width;
  final int? height;
  final String? loading;
  final String? fetchPriority;
  final String? srcset;
  final String? pageUrl;
  final List<String> issues;

  bool get isModernFormat {
    final lower = src.toLowerCase();
    return lower.endsWith('.webp') ||
        lower.endsWith('.avif') ||
        lower.endsWith('.svg');
  }

  Map<String, Object?> toJson() => {
    'src': src,
    'alt': alt,
    'hasAlt': hasAlt,
    'hasDimensions': hasDimensions,
    'hasLazyLoading': hasLazyLoading,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (loading != null) 'loading': loading,
    if (fetchPriority != null) 'fetchPriority': fetchPriority,
    if (srcset != null) 'srcset': srcset,
    if (pageUrl != null) 'pageUrl': pageUrl,
    'isModernFormat': isModernFormat,
    'issues': issues,
  };
}

/// Aggregate audit report for image SEO and Core Web Vitals optimization.
class ImageSeoReport {
  const ImageSeoReport({
    required this.totalImages,
    required this.imagesWithAlt,
    required this.imagesMissingAlt,
    required this.imagesWithDimensions,
    required this.imagesMissingDimensions,
    required this.imagesWithLazyLoading,
    required this.imagesInModernFormat,
    required this.findings,
  });

  final int totalImages;
  final int imagesWithAlt;
  final int imagesMissingAlt;
  final int imagesWithDimensions;
  final int imagesMissingDimensions;
  final int imagesWithLazyLoading;
  final int imagesInModernFormat;
  final List<ImageFinding> findings;

  double get altTextCoverage =>
      totalImages == 0 ? 100.0 : (imagesWithAlt / totalImages) * 100.0;

  double get dimensionCoverage =>
      totalImages == 0 ? 100.0 : (imagesWithDimensions / totalImages) * 100.0;

  Map<String, Object?> toJson() => {
    'totalImages': totalImages,
    'imagesWithAlt': imagesWithAlt,
    'imagesMissingAlt': imagesMissingAlt,
    'altTextCoveragePercent': double.parse(altTextCoverage.toStringAsFixed(1)),
    'imagesWithDimensions': imagesWithDimensions,
    'imagesMissingDimensions': imagesMissingDimensions,
    'dimensionCoveragePercent': double.parse(
      dimensionCoverage.toStringAsFixed(1),
    ),
    'imagesWithLazyLoading': imagesWithLazyLoading,
    'imagesInModernFormat': imagesInModernFormat,
    'findingsCount': findings.length,
    'findings': findings.map((f) => f.toJson()).toList(),
  };

  String toTerminalSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== Image SEO & Optimization Report ===\n');
    buffer.writeln('Total Images Analyzed:    $totalImages');
    buffer.writeln(
      'Alt Text Coverage:        ${altTextCoverage.toStringAsFixed(1)}% ($imagesWithAlt/$totalImages)',
    );
    buffer.writeln(
      'Dimension Attribute Rate: ${dimensionCoverage.toStringAsFixed(1)}% (Prevents CLS)',
    );
    buffer.writeln('Lazy-Loaded Images:       $imagesWithLazyLoading');
    buffer.writeln('Next-Gen Format (WebP/AVIF/SVG): $imagesInModernFormat\n');

    final withIssues = findings.where((f) => f.issues.isNotEmpty).toList();
    if (withIssues.isEmpty) {
      buffer.writeln('✓ All images comply with SEO and CLS best practices.');
    } else {
      buffer.writeln('Optimization Opportunities (${withIssues.length}):');
      for (final f in withIssues) {
        buffer.writeln('  * [${f.src}]');
        for (final issue in f.issues) {
          buffer.writeln('      - $issue');
        }
      }
    }
    return buffer.toString();
  }
}

/// Analyzer that evaluates images in HTML for SEO accessibility, Core Web Vitals (CLS),
/// and generates Google Image XML sitemaps.
class ImageSeoAnalyzer {
  const ImageSeoAnalyzer();

  /// Inspects all `<img>` elements within [html] and returns an [ImageSeoReport].
  ImageSeoReport analyzeHtml(String html, {String? pageUrl}) {
    final doc = html_parser.parse(html);
    final imgElements = doc.querySelectorAll('img');

    final findings = <ImageFinding>[];
    var withAlt = 0;
    var missingAlt = 0;
    var withDimensions = 0;
    var missingDimensions = 0;
    var withLazy = 0;
    var inModernFormat = 0;

    for (var i = 0; i < imgElements.length; i++) {
      final img = imgElements[i];
      final src = img.attributes['src']?.trim() ?? '';
      final alt = img.attributes['alt'];
      final widthStr = img.attributes['width'];
      final heightStr = img.attributes['height'];
      final loading = img.attributes['loading']?.toLowerCase();
      final fetchPriority = img.attributes['fetchpriority']?.toLowerCase();
      final srcset = img.attributes['srcset'];

      final issues = <String>[];

      // 1. Alt Text Analysis
      final hasAlt = alt != null && alt.trim().isNotEmpty;
      if (hasAlt) {
        withAlt++;
      } else {
        missingAlt++;
        issues.add(
          'Missing or empty alt text. Search crawlers and screen readers cannot understand image content.',
        );
      }

      // 2. Dimensions (CLS Prevention)
      final width = int.tryParse(widthStr ?? '');
      final height = int.tryParse(heightStr ?? '');
      final hasDimensions = width != null && height != null;
      if (hasDimensions) {
        withDimensions++;
      } else {
        missingDimensions++;
        issues.add(
          'Missing explicit width and height attributes. Can trigger Cumulative Layout Shift (CLS).',
        );
      }

      // 3. Lazy Loading & Priority
      final hasLazyLoading = loading == 'lazy';
      if (hasLazyLoading) {
        withLazy++;
      } else if (i > 0 && loading != 'eager') {
        issues.add(
          'Below-the-fold image should specify loading="lazy" for faster initial page load.',
        );
      }

      // 4. Format Check
      final isModern =
          src.endsWith('.webp') ||
          src.endsWith('.avif') ||
          src.endsWith('.svg');
      if (isModern) {
        inModernFormat++;
      } else if (src.endsWith('.png') ||
          src.endsWith('.jpg') ||
          src.endsWith('.jpeg')) {
        issues.add(
          'Consider serving next-gen format (WebP or AVIF) for reduced payload.',
        );
      }

      findings.add(
        ImageFinding(
          src: src,
          alt: alt,
          hasAlt: hasAlt,
          hasDimensions: hasDimensions,
          hasLazyLoading: hasLazyLoading,
          width: width,
          height: height,
          loading: loading,
          fetchPriority: fetchPriority,
          srcset: srcset,
          pageUrl: pageUrl,
          issues: issues,
        ),
      );
    }

    return ImageSeoReport(
      totalImages: imgElements.length,
      imagesWithAlt: withAlt,
      imagesMissingAlt: missingAlt,
      imagesWithDimensions: withDimensions,
      imagesMissingDimensions: missingDimensions,
      imagesWithLazyLoading: withLazy,
      imagesInModernFormat: inModernFormat,
      findings: findings,
    );
  }

  /// Generates a Google Image XML sitemap mapping pages to their embedded images.
  String generateImageSitemap(Map<String, List<ImageFinding>> pageImages) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
      'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
    );

    final sortedUrls = pageImages.keys.toList()..sort();
    for (final pageUrl in sortedUrls) {
      final images = pageImages[pageUrl] ?? const [];
      if (images.isEmpty) continue;

      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escape(pageUrl)}</loc>');
      for (final img in images) {
        if (img.src.isEmpty) continue;
        buf.writeln('    <image:image>');
        buf.writeln('      <image:loc>${_escape(img.src)}</image:loc>');
        if (img.hasAlt) {
          buf.writeln('      <image:title>${_escape(img.alt!)}</image:title>');
        }
        buf.writeln('    </image:image>');
      }
      buf.writeln('  </url>');
    }
    buf.writeln('</urlset>');
    return buf.toString();
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
