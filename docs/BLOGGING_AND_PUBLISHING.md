# MetaMantle Blogging, News & Content Publishing

Content publishing platforms require rapid content parsing, automated syndication feeds (RSS 2.0 and Atom 1.0), and rapid indexation through Google News XML sitemaps.

---

## 1. YAML Frontmatter Processing (`FrontmatterExtractor`)

Articles written in Markdown typically contain metadata at the head of the file formatted with YAML frontmatter delimiters (`---`).

`FrontmatterExtractor` parses frontmatter attributes with zero native dependencies:

```markdown
---
title: "The Architecture of Universal Web Head Management"
description: "How MetaMantle bridges client Flutter Web execution with zero-latency crawler SSR."
author: "Alex Rivera"
date: 2026-03-01T12:00:00Z
tags: "flutter, architecture, seo"
image: "https://blog.example.com/assets/banner.png"
---

# Article Content
...
```

```dart
const extractor = FrontmatterExtractor();
final doc = extractor.parse(rawMarkdown);

print(doc.title);        // "The Architecture of Universal Web Head Management"
print(doc.description);  // "How MetaMantle bridges client..."
print(doc.author);       // "Alex Rivera"
print(doc.body);         // Clean markdown body without frontmatter block
```

---

## 2. Universal RSS 2.0 & Atom 1.0 Feeds (`FeedGenerator`)

Syndication feeds are essential for news aggregators, podcast clients, RSS readers, and cross-platform feed indexing.

`FeedGenerator` produces valid XML feeds conforming to RSS 2.0 and Atom 1.0 standards:

```dart
const feedGen = FeedGenerator(
  feedTitle: 'MetaMantle Tech Dispatch',
  feedUrl: 'https://blog.example.com',
  feedDescription: 'Deep dives on Flutter Web and distributed backend engineering.',
);

final items = [
  FeedItem(
    id: 'post-101',
    title: doc.title!,
    url: 'https://blog.example.com/posts/head-architecture',
    summary: doc.description!,
    publishedAt: DateTime.utc(2026, 3, 1, 12),
    author: doc.author,
    categories: ['Flutter', 'SEO'],
  ),
];

final rssXml = feedGen.generateRss2(items);
final atomXml = feedGen.generateAtom(items);
```

---

## 3. Google News Sitemaps (`NewsSitemapGenerator`)

Google News requires specialized XML sitemaps with the `xmlns:news="http://www.google.com/schemas/sitemap-news/0.9"` namespace for time-sensitive article publication:

```dart
const newsGen = NewsSitemapGenerator();

final sitemapXml = newsGen.generate([
  NewsArticleItem(
    loc: 'https://blog.example.com/posts/head-architecture',
    publicationName: 'MetaMantle Engineering',
    publicationLanguage: 'en',
    publicationDate: DateTime.utc(2026, 3, 1, 12),
    title: 'Universal Head Management Framework Released',
    keywords: ['flutter', 'dart', 'seo'],
  ),
]);
```

