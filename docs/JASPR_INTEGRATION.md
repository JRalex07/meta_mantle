# MetaMantle Jaspr Web Framework Integration

Jaspr is the leading server-oriented web framework for Dart, providing fast server-side HTML rendering, component-based architectures, and lightweight hydration.

MetaMantle provides first-class adapters to unify SEO, document head rendering, and Markdown content handling within Jaspr applications.

---

## 1. Jaspr Architecture Overview

Jaspr renders component trees into HTML strings on the server and attaches client-side event listeners. 

MetaMantle's Jaspr integration bridges:
1. **`MetaMantleHead`**: Replaces manual `<head>` configuration with complete reactive SEO tags.
2. **`MetaMantleDocument`**: Generates full HTML document envelopes (`<!DOCTYPE html>`, `<html lang="...">`, `<head>`, `<body>`, and mounting nodes).
3. **`MetaMantleRouteAdapter`**: Handles data resolution, metadata synthesis, and server caching for Jaspr SSR routes.
4. **`MetaMantleContentAdapter`**: Extracts Markdown frontmatter for documentation portals and blog pages.

---

## 2. Rendering the Jaspr Document Shell

```dart
import 'package:meta_mantle/meta_mantle_server.dart';

final document = MetaMantleDocument(
  metadata: const WebMetadata(
    title: 'Jaspr Application',
    description: 'Ultra-fast server rendered Dart web app.',
    canonical: 'https://jaspr.example.com/',
    openGraph: OpenGraph(
      title: 'Jaspr Application',
      description: 'Ultra-fast server rendered Dart web app.',
      image: 'https://jaspr.example.com/assets/og.png',
    ),
  ),
  includeFlutterBootstrap: false,
);

final fullHtml = document.renderDocumentShell(
  bodyHtml: '<div id="app"><h1>Hello from Jaspr</h1></div>',
  currentUrl: 'https://jaspr.example.com/',
);
```

---

## 3. Jaspr + Flutter Hybrid Embedding

A common architecture in modern Dart web applications is a **hybrid shell**:
- Top-level marketing, documentation, or landing pages are rendered in pure HTML/Jaspr for instant search indexing and sub-50ms Time to First Byte.
- Complex interactive widgets (analytics dashboards, canvas graphics, games) are embedded as Flutter Web canvases inside a container element.

```dart
final hybridDoc = MetaMantleDocument(
  metadata: const WebMetadata(
    title: 'Interactive Analytics Dashboard',
    description: 'Real-time financial charts with server-rendered SEO.',
    canonical: 'https://app.example.com/dashboard/',
  ),
  includeFlutterBootstrap: true,
);

final html = hybridDoc.renderDocumentShell(
  bodyHtml: '''
    <header><nav><a href="/">Home</a></nav></header>
    <!-- Server-rendered fallback content for non-JS web crawlers -->
    <noscript><p>Financial summary: Q1 Volume \$4.8M</p></noscript>
    <!-- Flutter Web mounting target -->
    <div id="flutter_container"></div>
  ''',
  currentUrl: 'https://app.example.com/dashboard/',
);
```

