# Command Line Interface (CLI)

MetaMantle includes a unified CLI (`bin/meta_mantle.dart`) for development, building, verification, static SEO pre-rendering, Flutter Web acceleration, and automated CI pipelines.

Run the CLI using:
```bash
dart run meta_mantle <command> [options]
```

---

## 1. Primary Commands

### `meta_mantle build-web`
**Unified Flutter Web Static Build Engine.**
Orchestrates the entire Flutter Web build pipeline: compiles the Flutter application, resolves static route manifests and dynamic data patterns, pre-renders semantic HTML snapshots (`<article>`, `<form>`, `<details>`, `<table>`, lists, headings, links, products) from `MantleComponent` trees, injects SEO metadata into `<head>`, coordinates client hydration/bootstrap, and outputs XML sitemaps, `robots.txt`, and build reports.

```bash
dart run meta_mantle build-web [options]
```

#### Step-by-Step Build Workflow:
1. **Validation:** Checks for valid `pubspec.yaml`, `web/index.html`, and `meta_mantle.config.json`.
2. **Route Resolution:** Discovers static routes and expands dynamic patterns (`:id`, `:slug`) with local JSON data or programmatic manifests.
3. **Flutter Web Compilation:** Invokes `flutter build web` with `--release` (or `--wasm` / `--debug`) unless `--dry-run` is specified.
4. **HTML Snapshot Injection:** Injects route-specific metadata and semantic HTML into route-specific `index.html` files.
5. **Bootstrap Integration:** Injects prerender CSS styles and client startup coordination script (`window.__mantleClientReady`).
6. **Search Engine Discovery:** Generates `sitemap.xml` and `robots.txt`.
7. **Report Generation:** Generates `meta_mantle_report.json` with execution duration, route counts, and warnings.

#### Options:
- `--mode=<mode>`: Operational mode: `metadata`, `prerender`, or `hybrid` (default: `hybrid`).
- `--release`: Compiles Flutter Web in release mode (default: `true`, negate with `--no-release`).
- `--debug`: Compiles in debug mode (default: `false`).
- `--output=<dir>`: Output directory for generated static assets (default: `build/web`).
- `--base-href=<href>`: Base href for Flutter Web routing (default: `/`).
- `--wasm`: Enables native WebAssembly (`wasmGC`) compilation (default: `false`).
- `--dry-run`: Resolves routes and simulates generation without running Flutter build or writing files (default: `false`).
- `--clean`: Runs `flutter clean` before building (default: `false`).
- `--strict`: Fails build if any metadata or route warnings occur (default: `false`).
- `--config=<path>`: Path to configuration file (default: `meta_mantle.config.json`).
- `-v, --verbose`: Enables detailed logging (default: `false`).

---

### `meta_mantle build`
Injects route-specific metadata, Open Graph cards, and JSON-LD structured data into an existing Flutter `build/web` directory:
```bash
dart run meta_mantle build [options]
```
- `--config=<path>`: Path to configuration file (default: `meta_mantle.config.json`).
- `--input=<dir>`: Source compiled web directory (default: `build/web`).
- `--output=<dir>`: Target web build directory (default: `build/web`).
- `--strict`: Fails build if any route is missing a title or description.
- `--no-sitemap`: Skips generating `sitemap.xml`.
- `--no-robots`: Skips generating `robots.txt`.
- `--dry-run`: Simulates injection without writing files.
- `-v, --verbose`: Enables detailed logging.

---

### `meta_mantle web`
**Flutter Web Acceleration Subsystem.**
Audits web compilation readiness, configures multi-threaded WebAssembly (Wasm), and verifies web security headers (COOP/COEP).

#### `meta_mantle web analyze`
Analyzes project dependencies for Wasm compatibility and flags legacy web plugins:
```bash
dart run meta_mantle web analyze --project-dir=. --build-dir=build/web
```
- `--project-dir=<path>`: Root directory of Flutter project (default: `.`).
- `--build-dir=<path>`: Web build output directory (default: `build/web`).
- `--json`: Outputs audit results as JSON.

#### `meta_mantle web build`
Outputs recommended production Flutter Web build commands tailored to project configuration:
```bash
dart run meta_mantle web build --project-dir=. --wasm --tree-shake-icons
```

#### `meta_mantle web report`
Generates a comprehensive web performance and acceleration readiness report:
```bash
dart run meta_mantle web report --project-dir=. --build-dir=build/web
```

---

## 2. Verification & Diagnostics

### `meta_mantle doctor`
Runs comprehensive preflight diagnostics verifying Flutter SDK, Dart SDK, template `web/index.html`, configuration syntax, and asset directories:
```bash
dart run meta_mantle doctor --config=meta_mantle.config.json --input=build/web
```

### `meta_mantle validate`
Performs static schema validation on `meta_mantle.config.json`:
```bash
dart run meta_mantle validate --config=meta_mantle.config.json
```
- Verifies URL formats, scheme validity (`http`/`https`), and robots directive compliance.
- Validates data files referenced in dynamic route patterns.

### `meta_mantle inspect`
Prints all resolved static and dynamic routes along with resolved titles, descriptions, and canonical URLs without writing any files:
```bash
dart run meta_mantle inspect --config=meta_mantle.config.json
```

---

## 3. SEO Auditing & Inspection

### `meta_mantle inspect-url`
Inspects a single URL and prints resolved metadata, Open Graph cards, and JSON-LD schemas:
```bash
dart run meta_mantle inspect-url --url=https://example.com/products/keyboard
```
- `--url=<url>`: Target URL to inspect (mandatory).
- `--json`: Output report as JSON (default: `false`).
- `--allow-localhost`: Allow loopback/localhost requests for local development (default: `true`).

### `meta_mantle crawl`
Audits a live or staging site for SEO compliance:
```bash
dart run meta_mantle crawl --base-url=https://staging.example.com
```
- Discovers internal links recursively.
- Verifies HTTP 200 responses.
- Detects broken links (404/500), duplicate titles, missing meta descriptions, and invalid canonical URLs.
- Protected against SSRF: blocks private and link-local destinations.

### `meta_mantle preview`
Starts a lightweight local HTTP static web server to inspect generated static build routes in the browser:
```bash
dart run meta_mantle preview --config=meta_mantle.config.json --route=/about
```

### `meta_mantle report`
Generates a consolidated SEO audit report:
```bash
dart run meta_mantle report --config=meta_mantle.config.json --json
```

### `meta_mantle regression`
Compares a current crawl/audit against a baseline JSON snapshot to detect SEO regressions:
```bash
dart run meta_mantle regression --baseline=baseline_audit.json --current=current_audit.json
```
- Halts CI/CD if canonical URLs, titles, or descriptions regress or critical meta tags are removed.
- `--json`: Outputs comparison report as JSON.
