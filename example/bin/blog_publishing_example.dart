// ignore_for_file: avoid_print
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  print('========================================================');
  print(' MetaMantle Blog Publishing Engine Example');
  print('========================================================');

  // 1. Markdown Frontmatter Extraction
  const sampleMarkdownPost = '''---
title: "The Architecture of Universal Web Head Management"
description: "How MetaMantle bridges client Flutter Web execution with zero-latency crawler SSR."
date: 2026-03-01T12:00:00Z
author: "Alex Rivera"
tags: "flutter, architecture, web, seo"
image: "https://blog.metamantle.dev/images/universal-head.png"
---

# The Architecture of Universal Web Head Management

Web head management has traditionally been split between client-side Single Page Application (SPA) state and server prerendered HTML.

## The Dual-Engine Solution

By maintaining a pure-Dart core that compiles everywhere, MetaMantle renders identical, deterministic metadata tags across both client and server boundaries.
''';

  const extractor = FrontmatterExtractor();
  final postDoc = extractor.parse(sampleMarkdownPost);
  print('[Extracted Frontmatter]');
  print('  Title:          ${postDoc.title}');
  print('  Description:    ${postDoc.description}');
  print('  Author:         ${postDoc.author}');
  print('  Tags:           ${postDoc.tags}');
  print('  Body length:    ${postDoc.body.length} characters');

  // Convert to Jaspr / MetaMantle metadata
  const adapter = MetaMantleContentAdapter();
  final metadata = adapter.extractMetadata(
    markdownContent: sampleMarkdownPost,
    fallbackCanonical:
        'https://blog.metamantle.dev/posts/universal-head-architecture/',
  );
  print('\n[Metadata Model Created]');
  print('  Canonical:      ${metadata.canonical}');
  print('  Title:          ${metadata.title}');
  print('  Keywords:       ${metadata.keywords}');

  // 2. RSS 2.0 and Atom 1.0 Feeds Generation
  final feedArticles = [
    FeedItem(
      id: 'tag:blog.metamantle.dev,2026:post-1',
      title: postDoc.title ?? 'Untitled Post',
      url: 'https://blog.metamantle.dev/posts/universal-head-architecture/',
      summary: postDoc.description ?? '',
      contentHtml: '<p>${postDoc.description}</p>',
      author: postDoc.author ?? 'MetaMantle Team',
      publishedAt: DateTime.utc(2026, 3, 1, 12),
      categories: const ['Flutter', 'SEO', 'Dart'],
    ),
  ];

  const feedGen = FeedGenerator(
    feedTitle: 'MetaMantle Engineering Blog',
    feedUrl: 'https://blog.metamantle.dev',
    feedDescription: 'Deep dives on Flutter Web, Dart backend architecture, and technical SEO.',
  );

  final rssXml = feedGen.generateRss2(feedArticles);
  print('\n[RSS 2.0 Feed Preview (First 200 chars)]');
  print('${rssXml.substring(0, 200)}...');

  final atomXml = feedGen.generateAtom(feedArticles);
  print('\n[Atom 1.0 Feed Preview (First 200 chars)]');
  print('${atomXml.substring(0, 200)}...');

  // 3. Google News Sitemap Generation (<news:news>)
  final newsSitemapXml = const NewsSitemapGenerator().generate([
    NewsArticleItem(
      loc: 'https://blog.metamantle.dev/posts/universal-head-architecture/',
      publicationName: 'MetaMantle Tech Dispatch',
      publicationLanguage: 'en',
      publicationDate: DateTime.utc(2026, 3, 1, 12),
      title: postDoc.title ?? 'Tech Update',
    ),
  ]);
  print('\n[Google News XML Sitemap Preview]');
  print(newsSitemapXml);
  print('========================================================');
}
