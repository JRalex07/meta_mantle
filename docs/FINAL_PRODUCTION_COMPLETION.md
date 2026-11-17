# MetaMantle — Master Production Completion Checklist

This living checklist tracks the production completion, rendering strategies, DOM-first engine, Flutter Islands, SSR, CLI commands, E2E browser tests, and CI verification for MetaMantle.

---

## 1. Architecture & Rendering Strategies

| Feature | Existing Implementation | Missing / Target Behavior | Status |
| :--- | :--- | :--- | :---: |
| **`RenderingStrategy` Enum** | Only `BuildMode` (`metadata`, `prerender`, `hybrid`) existed. | First-class `RenderingStrategy` enum: `flutterCanvas`, `semanticDom`, `domWithFlutterIslands`. | IN PROGRESS |
| **Strategy A: Flutter Canvas** | Full-page CanvasKit/Wasm rendering over static snapshot. | Maintain standard Flutter Web lifecycle, routing, input, and accessibility. | VERIFIED |
| **Strategy B: Semantic DOM** | `MantleDomRenderer` existed in web interop, but build engine always loaded full Flutter canvas. | Output pure real HTML DOM nodes (`<h1>`, `<p>`, `<nav>`, `<a>`, `<button>`, `<article>`, `<main>`). Zero full-page Flutter canvas overlay. Chrome DevTools `elementFromPoint()` returns real semantic elements. | IN PROGRESS |
| **Strategy C: DOM + Flutter Islands** | Bootstrap adapter coordinated snapshot fade-out only. | Real semantic HTML document with Flutter scoped strictly inside designated container host(s) via `engineInitializer.initializeEngine({ hostElement })`. Surrounding DOM stays accessible. | IN PROGRESS |
| **Universal Component Model** | Component IR with text, images, nav, forms, cards. | Single source of truth rendering to Flutter widgets, native DOM nodes, and server HTML. Support `MantleIsland` component. | IN PROGRESS |

---

## 2. Static Build Engine & SSR

| Feature | Existing Implementation | Missing / Target Behavior | Status |
| :--- | :--- | :--- | :---: |
| **Static Route Generation** | Pre-renders routes from config & manifest. | Support strategy selection per build (`--rendering-strategy` flag & config option). | IN PROGRESS |
| **Dynamic Route Data** | Pattern expansion from JSON data files. | Dynamic parameters substituted into metadata, component tree, and canonical links. | VERIFIED |
| **Request-Time SSR** | `ServerEngine` and `ShelfAdapter` route handlers. | Real Shelf HTTP server handling dynamic products, status codes (200, 404, 500), ETag, Cache-Control. | VERIFIED |
| **Flutter Bootstrap Customization** | Standard Flutter `flutter_bootstrap.js` loaded. | Tailored bootstrap for each strategy: bypass in Semantic DOM, scoped `hostElement` in Flutter Islands. | IN PROGRESS |

---

## 3. SEO, HTML Conformance & Queue

| Feature | Existing Implementation | Missing / Target Behavior | Status |
| :--- | :--- | :--- | :---: |
| **JSON-LD Entity Merging** | Entity-level matching preserving `@graph` & independent schemas. | Preserve independent Products & Organization when updating single entity. | VERIFIED |
| **Internal HTML5 Validator** | `HtmlValidator` checking duplicates, semantics, tags. | Strict validation of attributes, headings, ARIA, Microdata. | VERIFIED |
| **External Nu Validator** | W3C Nu HTML Checker client with mock endpoint tests. | Conformance verification against `validator.w3.org/nu/`. | VERIFIED |
| **Regeneration Queue** | `FileSystemJobQueue` with FIFO crash recovery. | Persisted monotonic enqueue sequence for strict FIFO across all filesystems. | VERIFIED |

---

## 4. E2E Browser Automation & Verification

| Feature | Target / Test Path | Scope | Status |
| :--- | :--- | :--- | :---: |
| **Semantic DOM Inspection** | `e2e/tests/routes.spec.js` | DevTools `elementFromPoint(x, y)` returns `H1`, `P`, `NAV`, `A`, `BUTTON`. | PENDING |
| **Flutter Islands Verification** | `e2e/tests/routes.spec.js` | Flutter canvas confined to `#flutter-cart-island`. Surrounding DOM clickable. | PENDING |
| **Flutter Canvas Verification** | `e2e/tests/routes.spec.js` | Standard Flutter runtime startup and application surface mounting. | VERIFIED |
| **Desktop & Mobile Playwright** | `desktop-chromium`, `mobile-chromium` | Viewport responsiveness, zero horizontal overflow, deep-link refresh. | VERIFIED |
| **Shelf SSR HTTP Tests** | `test/ssr_http_integration_test.dart` | Status 200/404/500, ETag, Cache-Control, dynamic product data. | VERIFIED |

---

## 5. Documentation & Release Readiness

| Document | Purpose | Status |
| :--- | :--- | :---: |
| `docs/HTML_RENDERING.md` | Clarifies rendering strategies vs build modes, hydration vs replacement. | PENDING UPDATE |
| `docs/CLI_REFERENCE.md` | Full executable CLI command reference with flags and examples. | PENDING UPDATE |
| `docs/QUICK_START.md` | Step-by-step developer integration guide. | PENDING UPDATE |
| `README.md` | Accurate framework overview and feature matrix. | PENDING UPDATE |
| `CHANGELOG.md` | v0.3.0 release candidate notes. | PENDING UPDATE |
