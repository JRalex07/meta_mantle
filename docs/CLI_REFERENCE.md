# MetaMantle CLI Reference Manual

MetaMantle provides an extensive, production-grade CLI suite for universal application compilation, Flutter Web static rendering, SEO verification, automated crawlers, local previewing, cache inspection, and Core Web Vitals optimization.

---

## Command Overview

| Command Group | Purpose | Primary Options |
|---|---|---|
| `build` | Static head pre-rendering based on config and manifest | `--config`, `--manifest`, `--output`, `--watch` |
| `build-web` | Universal Flutter Web Build Engine (HTML + Flutter JS/Wasm) | `--mode`, `--config`, `--strict`, `--no-flutter-build`, `--no-sitemap` |
| `validate` | Validates static output against SEO and accessibility rules | `--dir`, `--strict`, `--min-score`, `--fail-on-warnings` |
| `inspect` | In-depth audit of a specific route or output file | `--file`, `--format`, `--verbose` |
| `doctor` | Environment and project configuration diagnostics | `--verbose`, `--fix` |
| `inspect-url` | Real-time HTTP header and crawler inspection of live URLs | `--url`, `--user-agent`, `--follow-redirects` |
| `crawl` | Recursive site crawler with link checking and security audit | `--url`, `--max-depth`, `--concurrency`, `--respect-robots` |
| `preview` | Embedded shelf HTTP server with SPA fallback and MIME types | `--dir`, `--port`, `--host`, `--spa` |
| `report` | Scans on-disk HTML for SEO tags, headings, and JSON-LD | `--dir`, `--json`, `--output` |
| `regression` | Compares pre-render snapshots across builds or baselines | `--baseline`, `--current`, `--diff` |
| `web` | Web acceleration tools and Skwasm/Wasm headers | `accelerate`, `headers` |
| `html` | HTML document validation and element inspection | `validate`, `inspect` |
| `routes` | Inspect, validate, and scaffold route manifests | `list`, `validate`, `generate` |
| `cache` | Inspect disk cache metrics and clear cached pre-renders | `inspect`, `clear` |

---

## 1. `build-web`

Executes the universal build pipeline. Compiles Flutter Web artifacts and pre-renders semantic HTML trees with injected SEO metadata into `build/web`.

```bash
dart run meta_mantle build-web [options]
```

### Options:
- `--mode=<static|hybrid|universal>`: Build rendering mode.
  - `static`: Pre-renders pure semantic HTML and metadata without bundling heavy JS/CanvasKit.
  - `hybrid` (default): Pre-renders semantic HTML snapshots that smoothly fade out once Flutter Web hydrates.
  - `universal`: Generates HTML for initial load and hydrates client DOM via MetaMantle's lightweight DOM reconciler.
- `--config=<path>`: Path to configuration file (default: `meta_mantle.yaml`).
- `--manifest=<path>`: Route manifest entrypoint (default: auto-detected from `lib/routes.dart`, `tool/routes.dart`).
- `--strict`: Enable strict mode (fails build if any route encounters unsupported nodes or validation errors).
- `--[no-]flutter-build`: Whether to invoke `flutter build web` before pre-rendering (default: enabled).
- `--[no-]sitemap`: Generate `sitemap.xml` and `robots.txt` (default: enabled).

### Exit Codes:
- `0`: Build succeeded with valid HTML and metadata.
- `1`: Build failure or strict validation error.

---

## 2. `preview`

Spins up an embedded HTTP server to preview static pre-rendered routes, verify client hydration handshakes, and test SPA fallback.

```bash
dart run meta_mantle preview [options]
```

### Options:
- `-d, --dir=<path>`: Root directory to serve (default: `build/web`).
- `-p, --port=<int>`: Port number to bind (default: `8080`).
- `-a, --host=<host>`: Network interface host (default: `localhost`).
- `--[no-]spa`: Enable single-page application fallback to `index.html` (default: enabled).

---

## 3. `html`

Dedicated command group for validating HTML structure and inspecting rendered tags.

### `html validate`
```bash
dart run meta_mantle html validate --dir build/web [--strict]
```
Checks for:
- Valid `<!DOCTYPE html>`, `<html>`, `<head>`, and `<body>`.
- Mandatory `<title>`, `<meta name="description">`, and `<link rel="canonical">`.
- Cumulative Layout Shift (CLS) attribute presence on `<img>`.

### `html inspect`
```bash
dart run meta_mantle html inspect --file build/web/index.html [--json]
```
Parses and displays metadata, Open Graph cards, Twitter cards, H1/H2 heading hierarchy, and JSON-LD structured data blocks.

---

## 4. `routes`

Inspect and scaffold application route definitions.

### `routes list`
Displays all configured routes, paths, and metadata titles from the project manifest.

### `routes validate`
Validates that declared paths are valid URI paths without illegal directory traversal or malformed characters.

### `routes generate`
Scaffolds a production-ready `routes.dart` template with universal components and metadata:
```bash
dart run meta_mantle routes generate --output lib/routes.dart
```

---

## 5. `cache`

Manage build artifacts and incremental regeneration caches.

### `cache inspect`
```bash
dart run meta_mantle cache inspect --dir .mantle_cache
```
Displays total cached files, storage size, and recent cache entries.

### `cache clear`
```bash
dart run meta_mantle cache clear --dir .mantle_cache
```
Purges cached pre-render files safely.

---

## 6. `validate` & `report`

- `dart run meta_mantle validate --dir build/web`: Audits generated site against SEO scoring thresholds.
- `dart run meta_mantle report --dir build/web`: Produces an on-disk summary of all pre-rendered HTML files, titles, descriptions, and headings.

---

## 7. `crawl` & `inspect-url`

- `dart run meta_mantle crawl --url http://localhost:8080`: Recursively crawls pages, checks link health, detects broken links (404), and checks for SSR readiness.
- `dart run meta_mantle inspect-url --url https://example.com`: Fetches a remote URL with crawler User-Agent emulation (`Googlebot`, `bingbot`, `Twitterbot`) to verify dynamic rendering.
