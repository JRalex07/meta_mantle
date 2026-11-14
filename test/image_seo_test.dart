import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/src/seo/image_seo.dart';

void main() {
  group('ImageSeoAnalyzer', () {
    const analyzer = ImageSeoAnalyzer();

    test('analyzes image attributes correctly', () {
      const html = '''
<!DOCTYPE html>
<html>
  <body>
    <!-- Complete image -->
    <img src="/hero.webp" alt="Hero banner" width="1200" height="600" />
    
    <!-- Incomplete image: missing alt, dimensions, old format -->
    <img src="/logo.png" />

    <!-- Below-the-fold lazy image -->
    <img src="/product.avif" alt="Product thumbnail" width="300" height="300" loading="lazy" />
  </body>
</html>
''';

      final report = analyzer.analyzeHtml(html, pageUrl: 'https://example.com');

      expect(report.totalImages, equals(3));
      expect(report.imagesWithAlt, equals(2));
      expect(report.imagesMissingAlt, equals(1));
      expect(report.altTextCoverage, closeTo(66.6, 0.1));

      expect(report.imagesWithDimensions, equals(2));
      expect(report.imagesMissingDimensions, equals(1));
      expect(report.dimensionCoverage, closeTo(66.6, 0.1));

      expect(report.imagesWithLazyLoading, equals(1));
      expect(report.imagesInModernFormat, equals(2)); // webp and avif

      // Findings verification
      final logoFinding = report.findings.firstWhere(
        (f) => f.src == '/logo.png',
      );
      expect(logoFinding.hasAlt, isFalse);
      expect(logoFinding.hasDimensions, isFalse);
      expect(logoFinding.isModernFormat, isFalse);
      expect(logoFinding.issues.length, greaterThanOrEqualTo(2));

      final summary = report.toTerminalSummary();
      expect(summary, contains('Image SEO & Optimization Report'));
      expect(summary, contains('Total Images Analyzed:    3'));
    });

    test('generates valid Google Image XML sitemap', () {
      final pageImages = {
        'https://example.com/': [
          const ImageFinding(
            src: 'https://example.com/banner.webp',
            alt: 'Homepage Banner & Promotion',
            hasAlt: true,
            hasDimensions: true,
            hasLazyLoading: false,
          ),
          const ImageFinding(
            src: 'https://example.com/icon.svg',
            alt: null,
            hasAlt: false,
            hasDimensions: true,
            hasLazyLoading: false,
          ),
        ],
        'https://example.com/products': [
          const ImageFinding(
            src: 'https://example.com/shoes.avif',
            alt: 'Running Shoes <Top Pick>',
            hasAlt: true,
            hasDimensions: true,
            hasLazyLoading: true,
          ),
        ],
      };

      final sitemap = analyzer.generateImageSitemap(pageImages);

      expect(sitemap, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(
        sitemap,
        contains('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'),
      );
      expect(
        sitemap,
        contains(
          'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"',
        ),
      );
      expect(sitemap, contains('<loc>https://example.com/</loc>'));
      expect(
        sitemap,
        contains('<image:loc>https://example.com/banner.webp</image:loc>'),
      );
      expect(
        sitemap,
        contains('<image:title>Homepage Banner &amp; Promotion</image:title>'),
      );
      expect(
        sitemap,
        contains('<image:title>Running Shoes &lt;Top Pick&gt;</image:title>'),
      );
      expect(sitemap, contains('</urlset>'));
    });
  });
}
