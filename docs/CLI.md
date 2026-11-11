# Command Line Interface (CLI)

MetaMantle includes a CLI (`bin/meta_mantle.dart`) for development, building, verification, and automated CI pipelines.

---

## 1. CLI Commands

### `meta_mantle build`
Builds static HTML files and sitemaps for all declared routes:
```bash
dart run meta_mantle build [options]
```
- `--config=<path>`: Path to configuration file (default: `meta_mantle.config.json`).
- `--output=<dir>`: Target web build directory (default: `build/web`).
- `--strict`: Fails build if any route is missing a title or description.
- `--incremental`: Skips re-rendering routes with unchanged fingerprints.

---

### `meta_mantle crawl`
Audits a live or staging site for SEO compliance. Localhost and private destinations are denied by default by `CrawlerInspector`; the CLI does not silently enable a development exception:
```bash
dart run meta_mantle crawl --url=https://staging.example.com --concurrency=5
```
- Discovers internal links recursively.
- Verifies HTTP 200 responses.
- Detects broken links (404/500), duplicate titles, missing meta descriptions, and invalid canonical URLs.

---

### `meta_mantle preview`
Starts a lightweight local HTTP static web server to inspect the generated build:
```bash
dart run meta_mantle preview --port=8080 --dir=build/web
```

---

### `meta_mantle inspect-url`
Inspects a single URL and prints resolved metadata, Open Graph cards, and JSON-LD schemas:
```bash
dart run meta_mantle inspect-url https://example.com/products/basmati-rice
```
Crawler requests follow at most five redirects after validating every destination, reject HTTPS downgrades and loops, cap response bodies at 2 MiB, and use 10-second per-hop / 30-second total budgets. The library API offers an explicit loopback-only opt-in for trusted local development; there is no CLI environment-based bypass.
For the one-URL inspection command only, trusted local development can explicitly opt in with `--allow-localhost`; this option never permits private or link-local addresses. The recursive `crawl` command has no localhost opt-in.

---

### `meta_mantle report`
Generates a markdown or JSON audit report of the static build or crawl output.
```bash
dart run meta_mantle report --format=markdown --output=seo_audit.md
```

