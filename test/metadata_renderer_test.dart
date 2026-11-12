import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/src/core/metadata_renderer.dart';
import 'package:meta_mantle/src/models/metadata.dart';

void main() {
  group('MetadataRenderer', () {
    const renderer = MetadataRenderer();

    test('applies title template and inherited description', () {
      final tags = renderer.render(
        const WebMetadata(title: 'Rice'),
        config: const WebHeadConfig(
          titleTemplate: '%s | Store',
          defaultDescription: 'Default description',
          baseUrl: 'https://example.com',
        ),
      );
      expect(
        tags.firstWhere((tag) => tag.key == 'title').textContent,
        'Rice | Store',
      );
      expect(
        tags
            .firstWhere((tag) => tag.key == 'description')
            .attributes['content'],
        'Default description',
      );
    });

    test('resolves relative canonical and social image URLs', () {
      final tags = renderer.render(
        const WebMetadata(
          canonical: '/items/rice',
          openGraph: OpenGraphMetadata(image: '/og/rice.png'),
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );
      expect(
        tags.firstWhere((tag) => tag.key == 'canonical').attributes['href'],
        'https://example.com/items/rice',
      );
      expect(
        tags.firstWhere((tag) => tag.key == 'og:image').attributes['content'],
        'https://example.com/og/rice.png',
      );
    });

    test('rejects non-http URL schemes', () {
      expect(
        () => renderer.render(
          const WebMetadata(canonical: 'javascript:alert(1)'),
          config: const WebHeadConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
    });

    test(
      'requires an absolute canonical URL when no base URL is configured',
      () {
        expect(
          () => renderer.render(const WebMetadata(canonical: '/products/rice')),
          throwsFormatException,
        );
      },
    );

    test('rejects empty metadata URLs', () {
      expect(
        () => renderer.render(
          const WebMetadata(openGraph: OpenGraphMetadata(image: ' ')),
          config: const WebHeadConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
    });

    test('rejects canonical URLs containing query strings or fragments', () {
      expect(
        () => renderer.render(
          const WebMetadata(canonical: 'https://example.com/page?campaign=x'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(canonical: 'https://example.com/page#section'),
        ),
        throwsFormatException,
      );
    });

    test('rejects conflicting custom metadata identities', () {
      expect(
        () => renderer.render(
          const WebMetadata(
            description: 'Page description',
            customMeta: [
              WebMetaTag(
                key: 'another-description',
                name: 'description',
                content: 'Conflicting description',
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });

    test('serializes JSON-LD with script-breaking characters escaped', () {
      final jsonLd = JsonLd({'@type': 'Thing', 'name': '</script><script>x'});
      expect(jsonLd.toSafeScriptJson(), isNot(contains('</script>')));
      expect(jsonLd.toSafeScriptJson(), contains(r'\u003C'));
    });

    group('Title template deduplication and fallback regression tests', () {
      const config = MetaMantleConfig(
        siteName: 'MetaMantle Store',
        defaultTitle: 'MetaMantle Store',
        titleTemplate: '%s | MetaMantle Store',
        baseUrl: 'https://example.com',
      );

      test('applies title template to normal subpage', () {
        final tags = renderer.render(
          const WebMetadata(title: 'About Us'),
          config: config,
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'About Us | MetaMantle Store',
        );
      });

      test('does not duplicate title when page title matches siteName', () {
        final tags = renderer.render(
          const WebMetadata(title: 'MetaMantle Store'),
          config: config,
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'MetaMantle Store',
        );
      });

      test('does not duplicate title when page title matches defaultTitle', () {
        final tags = renderer.render(
          const WebMetadata(title: 'MetaMantle Store'),
          config: const MetaMantleConfig(
            defaultTitle: 'MetaMantle Store',
            titleTemplate: '%s | MetaMantle Store',
            baseUrl: 'https://example.com',
          ),
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'MetaMantle Store',
        );
      });

      test(
        'does not duplicate when page title already contains template suffix',
        () {
          final tags = renderer.render(
            const WebMetadata(title: 'About Us | MetaMantle Store'),
            config: config,
          );
          expect(
            tags.firstWhere((t) => t.key == 'title').textContent,
            'About Us | MetaMantle Store',
          );
        },
      );

      test('respects applyTitleTemplate: false', () {
        final tags = renderer.render(
          const WebMetadata(
            title: 'Special Summer Campaign',
            applyTitleTemplate: false,
          ),
          config: config,
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'Special Summer Campaign',
        );
      });

      test('uses defaultTitle without template when page title is null', () {
        final tags = renderer.render(const WebMetadata(), config: config);
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'MetaMantle Store',
        );
      });

      test('uses defaultTitle fallback when page title is empty string', () {
        final tags = renderer.render(
          const WebMetadata(title: ''),
          config: config,
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'MetaMantle Store',
        );
      });

      test('returns plain title when titleTemplate is null', () {
        final tags = renderer.render(
          const WebMetadata(title: 'Products'),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        );
        expect(
          tags.firstWhere((t) => t.key == 'title').textContent,
          'Products',
        );
      });
    });
  });
}
