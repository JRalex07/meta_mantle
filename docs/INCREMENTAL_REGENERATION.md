# Incremental Static Regeneration & Manifests

MetaMantle supports content-fingerprinted incremental static generation (`lib/src/builder/incremental_manifest.dart`), allowing large static sites to regenerate in seconds rather than hours.

---

## 1. The Challenge of Large Static Builds

When an e-commerce or publishing site has 10,000+ pages, rebuilding every page on every git commit or deploy is computationally expensive and slow. Most pages have not changed their data, templates, or metadata.

---

## 2. Content Fingerprinting & `BuildManifest`

MetaMantle computes a deterministic SHA-256 fingerprint for every route:
```
fingerprint = sha256( template_hash + route_path + data_payload + metadata_hash )
```

During static building, `BuildManifest` records:
- `path`: Target route path (`/products/basmati-rice`).
- `outputPath`: Output HTML file (`build/web/products/basmati-rice/index.html`).
- `fingerprint`: SHA-256 hash of all input parameters.
- `builtAt`: Build timestamp.

---

## 3. Incremental Build Mode

When building with `--incremental`:
```bash
dart run bin/meta_mantle.dart build --incremental
```

1. MetaMantle loads `.metamantle/manifest.json` from the previous build.
2. For each route, computes the prospective fingerprint.
3. If the fingerprint matches and the output file exists, the page is marked **`SKIPPED`** (0ms cost).
4. Only routes with modified data or changed templates are rendered and written to disk.
5. Sitemaps and search indexes are updated to reflect new and modified routes.

