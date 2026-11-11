# MetaMantle Documentation Index

Welcome to the **MetaMantle** technical documentation. This directory contains comprehensive guides, architectural references, security audits, and operational manuals for Flutter Web, static site generation, and native Dart server rendering.

---

## 1. Getting Started
- **[Getting Started Guide](GETTING_STARTED.md)** — High-level walkthrough of MetaMantle, choosing an engine, and initial setup.
- **[Installation Guide](INSTALLATION.md)** — Dependency declarations, Git installation, platform requirements, and SDK compatibility.
- **[Quick Start](QUICK_START.md)** — Minimal working examples for Flutter Web, static HTML generation, and Dart SSR.

---

## 2. Core Architecture & Concepts
- **[Architecture Deep-Dive](ARCHITECTURE.md)** — Tripartite architecture (Engine A: Runtime, Engine B: Static, Engine C: Native SSR).
- **[Core Package Overview](CORE.md)** — Pure Dart core primitives, models, and zero-Flutter dependency guarantees.
- **[Runtime Engine](RUNTIME.md)** — Reactive DOM reconciler, monotonic generation tokens, and parent scope restoration.
- **[Static Site Generation](STATIC_GENERATION.md)** — AST-based HTML injection, incremental generation manifests, and preflight validation.
- **[Native Server Rendering](SERVER_RENDERING.md)** — Pure Dart request-time rendering, zero-JS crawler payloads, and Shelf adapter.
- **[Semantic HTML Rendering](HTML_RENDERING.md)** — Pure Dart virtual DOM tree (`ElementNode`, `TextNode`, `RawHtmlNode`) and HTML sanitization.
- **[API Reference](API.md)** — Comprehensive specification of widgets, models, builders, engines, and CLI parameters.

---

## 3. Data Integration & Caching
- **[Universal Database Providers](DATABASE_PROVIDERS.md)** — SQL (`RelationalDatabaseAdapter`), NoSQL (`DocumentDatabaseAdapter`), memory, and data contracts.
- **[REST & GraphQL Data Providers](REST_GRAPHQL.md)** — Secure HTTP data loading, in-line SSRF guards, timeouts, and streaming bounds.
- **[Caching Architecture](CACHING.md)** — True access-order LRU eviction, single-flight locking, tag invalidation, and metrics.
- **[HTTP Caching & ETags](HTTP_CACHING.md)** — RFC 7232 conditional requests, weak ETags, stale-while-revalidate, and stale-if-error.

---

## 4. Vertical Solutions & Engines
- **[E-Commerce SEO](ECOMMERCE_SEO.md)** — Product models, Google Search Central JSON-LD, inventory invalidation, and Merchant Center feeds.
- **[Documentation Portals](DOCUMENTATION_SITES.md)** — YAML frontmatter, version canonicalization, search indexing, and `/llms.txt`.
- **[Blogging & Publishing](BLOGGING_AND_PUBLISHING.md)** — Article/BlogPosting schemas, RSS 2.0 / Atom 1.0 feeds, and Google News sitemaps.
- **[SaaS & Multi-Tenancy](SAAS_AND_MULTITENANT.md)** — Host injection defense, custom domain mapping, and tenant-isolated caching.
- **[Landing Page SEO](LANDING_PAGE_SEO.md)** — High-converting social unfurling, FAQ schemas, and conversion optimization.
- **[Social Image Generation](SOCIAL_IMAGE_GENERATION.md)** — Pure Dart SVG card synthesis, OpenGraph dimensions, and LRU output caching.

---

## 5. SEO Specifications & Technical Standards
- **[Structured Data (JSON-LD)](STRUCTURED_DATA.md)** — 13 Schema.org builders with Unicode character escaping against XSS.
- **[Multilingual SEO & Hreflang](MULTILINGUAL_SEO.md)** — Reciprocal hreflang validation and localized routing.
- **[Sitemaps & Chunking](SITEMAPS.md)** — Google sitemap XML generation, 50,000 URL chunking, and image extensions.
- **[SEO Features & Tag Support](SEO_FEATURES.md)** — Complete catalog of meta tags, Twitter cards, Open Graph, and resource hints.
- **[SEO Limitations](SEO_LIMITATIONS.md)** — Realistic technical assessment of search crawler behaviors and client hydration constraints.

---

## 6. Framework Integrations
- **[Flutter Web Integration](FLUTTER_INTEGRATION.md)** — Declarative `MetaHead` widget lifecycle, GoRouter wrapping, and WebAssembly compilation.
- **[Jaspr Web Integration](JASPR_INTEGRATION.md)** — Jaspr document shells, `JasprTagDescriptor` parity, and hybrid Flutter embedding.
- **[Framework Adapters](FRAMEWORK_ADAPTERS.md)** — Connecting MetaMantle to Shelf, Jaspr, Dart Frog, and standalone servers.

---

## 7. Operations, Deployment & Tooling
- **[Routing & Hosting Guide](ROUTING_AND_HOSTING.md)** — Production hosting recipes for GitHub Pages, Firebase, Vercel, Netlify, and Docker.
- **[CLI Tooling Guide](CLI.md)** — Command-line workflows: `build`, `validate`, `inspect`, `doctor`, `inspect-url`, `crawl`, and `regression`.
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** — Solutions for common issues: strict validation failures, tab switching, and fonts.
- **[Performance & Concurrency](PERFORMANCE.md)** — Concurrency benchmarks, ring buffers, and memory bounds.
- **[Migration Guide](MIGRATION.md)** — Transitioning from React Helmet, Next.js Metadata, or legacy packages.

---

## 8. Governance, Stability & Reports
- **[API Stability Policy](API_STABILITY.md)** — Public API guarantees, deprecation cycles, and breaking change rules.
- **[Integration Contract](INTEGRATION_CONTRACT.md)** — Formal integration contract for consuming applications (e.g. landing website).
- **[Release Readiness Checklist](RELEASE_READINESS.md)** — Quality gates and verification criteria for production releases.
- **[Repository Cleanup Report](REPOSITORY_CLEANUP_REPORT.md)** — Audit report on GitHub Pages removal and credential scanning.
- **[Verification & Repair Report](VERIFICATION_AND_REPAIR_REPORT.md)** — Subsystem audit and verification test results.
- **[Execution Checkpoint](EXECUTION_CHECKPOINT.md)** — Ongoing execution status and verified milestones.
