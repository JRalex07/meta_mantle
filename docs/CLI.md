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
Audits your live site or local staging server for SEO compliance:
```bash
dart run meta_mantle crawl --url=http://localhost:8080 --concurrency=5
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

---

### `meta_mantle report`
Generates a markdown or JSON audit report of the static build or crawl output.
```bash
dart run meta_mantle report --format=markdown --output=seo_audit.md
```

