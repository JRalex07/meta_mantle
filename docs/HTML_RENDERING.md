# Semantic HTML Rendering & Progressive Enhancement

MetaMantle's HTML rendering subsystem (`lib/src/html/`) creates semantic, accessible, SEO-optimized HTML documents directly in pure Dart.

---

## 1. The Need for Semantic HTML in Flutter Web

Search engine crawlers (Google, Bing, DuckDuckGo) execute semantic parsers that extract page content from standard HTML elements: `<h1-h6>`, `<p>`, `<article>`, `<section>`, `<nav>`, `<table>`, and `<img>`.

When a client-only Flutter app loads, bots inspect the initial HTML payload. If the body is an empty `<div id="app"></div>`, indexing may be delayed or degraded.

MetaMantle solves this by serving **complete semantic HTML directly inside the initial document body**. When progressive enhancement is enabled, Flutter Web initializes over the top of the semantic document without content layout shifts.

---

## 2. The `H` Node Builder

MetaMantle provides typed helper factories via `H`:

| Factory | Target Element | Description |
|---|---|---|
| `H.h1(text)` - `H.h6(text)` | `<h1>` - `<h6>` | Semantic heading tags |
| `H.p(text)` | `<p>` | Paragraph text |
| `H.a(href, text)` | `<a href="...">` | Hyperlinks with target and rel controls |
| `H.img(src, alt)` | `<img src="..." alt="...">` | Accessible image element |
| `H.header(children)` | `<header>` | Semantic document/section header |
| `H.nav(children)` | `<nav>` | Navigation container |
| `H.article(children)` | `<article>` | Self-contained article node |
| `H.section(children)` | `<section>` | Generic document section |
| `H.footer(children)` | `<footer>` | Semantic document footer |
| `H.ul(items)` / `H.ol(items)` | `<ul>` / `<ol>` | Ordered and unordered lists |
| `H.table(headers, rows)` | `<table>` | Structured tabular data |
| `H.raw(sanitizedHtml)` | Raw HTML | Safe raw markup processed through sanitizer |

---

## 3. Strict HTML Sanitization

To prevent Cross-Site Scripting (XSS) when rendering user-submitted or CMS rich text, `HtmlSanitizer` runs an allowlist filter:

```dart
final clean = HtmlSanitizer.sanitize(dirtyHtml);
```

### Sanitizer Security Rules:
- **Disallowed Elements Stripped**: `<script>`, `<iframe>`, `<object>`, `<embed>`, `<form>`, `<input>`, `<link>`, `<style>`.
- **Dangerous Attributes Stripped**: All `on*` event handlers (`onclick`, `onload`, `onerror`), and `style` attributes.
- **Unsafe Protocols Blocked**: `javascript:`, `vbscript:`, and `data:` schemes are stripped from `href` and `src`. Only `http://`, `https://`, `mailto:`, `tel:`, and relative paths are preserved.

---

## 4. Progressive Enhancement & Flutter Bootstrapping

When `includeFlutterBootstrap` is set to `true`:
1. The server renders the full semantic HTML document.
2. An initial content wrapper `<div id="metamantle-content">...</div>` is included.
3. The Flutter web bootstrap script (`flutter_bootstrap.js` or `flutter.js`) is injected at the bottom of `<body>`.
4. The page appears instantly to human users and crawlers alike. Once Flutter's canvas or WebAssembly engine boots, Flutter mounts its view.

