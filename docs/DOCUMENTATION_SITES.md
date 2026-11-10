# MetaMantle Documentation Portals & Developer Sites

Documentation portals require specialized SEO handling: version canonicalization, instant search indexing, heading hierarchy extraction, and machine-readable context files for AI coding assistants (`/llms.txt`).

---

## 1. Documentation Version Management (`DocVersionPolicy`)

When documentation maintains multiple release versions (`/docs/v1/`, `/docs/v2/`, `/docs/latest/`), older version documentation often competes with latest versions in search indexes, cannibalizing organic traffic.

`DocVersionPolicy` automates version governance:
- **Canonicalization to Latest**: Routes for historical versions (e.g. `/docs/v1/installation/`) specify canonical links pointing to the equivalent page in `/docs/latest/installation/`.
- **Automated `noindex` for Outdated Versions**: Historical versions automatically receive `noindex, follow`, keeping crawler link equity while preventing search result pollution.
- **Latest Version Self-Canonicalization**: The active version (`/docs/latest/`) self-canonicalizes and receives `index, follow`.

```dart
const policy = DocVersionPolicy(
  baseDocsUrl: 'https://docs.metamantle.dev/docs',
  latestVersion: 'latest',
  supportedVersions: ['latest', 'v1', 'v2'],
  canonicalizeToLatest: true,
  noindexOlderVersions: true,
);

final decision = policy.evaluate('/docs/v1/getting-started');
// canonicalUrl: 'https://docs.metamantle.dev/docs/latest/getting-started/'
// robots: 'noindex, follow'
// isLatest: false
```

---

## 2. In-Memory Search Indexing (`DocSearchIndexer`)

Documentation portals require instant client-side full-text search without heavyweight external search infrastructure.

`DocSearchIndexer` parses Markdown headings (`#`, `##`, `###`) to produce hierarchical search indexes with contextual breadcrumbs:

```dart
const indexer = DocSearchIndexer();

final entries = indexer.extractEntries(
  pageTitle: 'Getting Started',
  pageUrl: 'https://docs.metamantle.dev/docs/latest/getting-started',
  markdownContent: markdownSource,
);

// Generates serialized JSON index for client search engines
final jsonIndex = indexer.generateJsonIndex(entries);
```

Sample generated entry:
```json
{
  "title": "Getting Started",
  "url": "https://docs.metamantle.dev/docs/latest/getting-started#installation",
  "section": "Installation",
  "hierarchy": ["Getting Started", "Installation"],
  "content": "Add meta_mantle to your pubspec.yaml dependencies."
}
```

---

## 3. AI Agent Context Generation (`/llms.txt`)

LLMs and AI agents (Cursor, Copilot, Antigravity) consume `/llms.txt` to discover repository documentation structures without scraping rendered HTML.

`LlmsTxtGenerator` emits structured Markdown indexes adhering to the `/llms.txt` specification:

```dart
const generator = LlmsTxtGenerator(
  projectName: 'MetaMantle Documentation',
  projectSummary: 'Universal SEO and SSR framework for Dart and Flutter.',
  documentationBaseUrl: 'https://docs.metamantle.dev',
);

final llmsTxt = generator.generate(
  pages: [
    (
      title: 'Architecture Guide',
      path: '/docs/latest/architecture',
      summary: 'Pure-Dart core, runtime engine, and server SSR architecture.',
    ),
    (
      title: 'Jaspr Integration',
      path: '/docs/latest/jaspr',
      summary: 'Building server-rendered Jaspr web apps with MetaMantle.',
    ),
  ],
);
```

