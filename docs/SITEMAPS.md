# Sitemaps & Robots Automation

MetaMantle automatically generates search engine sitemaps, sitemap index files, and `robots.txt` configuration (`lib/src/seo/sitemap_index.dart`).

---

## 1. Google Protocol Compliance

Standard XML sitemaps have strict limits established by search engines:
- Maximum **50,000 URLs** per individual sitemap file.
- Maximum **50MB uncompressed file size**.

When sites exceed these thresholds, MetaMantle's `SitemapGenerator` automatically splits entries across chunked sitemap files (`sitemap_1.xml`, `sitemap_2.xml`) and generates a master `sitemap_index.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemaps/sitemap_1.xml</loc>
    <lastmod>2026-11-10T00:00:00.000Z</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemaps/sitemap_2.xml</loc>
    <lastmod>2026-11-10T00:00:00.000Z</lastmod>
  </sitemap>
</sitemapindex>
```

---

## 2. Rich Sitemap Extensions

MetaMantle supports sitemap extensions:
- **Image Sitemaps (`xmlns:image`)**: Emits `<image:image>`, `<image:loc>`, `<image:title>`, `<image:caption>` enabling Google Image Search indexing.
- **Multilingual Alternatives (`xmlns:xhtml`)**: Injects `<xhtml:link rel="alternate" hreflang="..." href="..." />` inside urlset items.

---

## 3. Robots.txt Generation

MetaMantle generates standards-compliant `robots.txt` files pointing directly to the sitemap index:

```text
User-agent: *
Allow: /

Sitemap: https://example.com/sitemap_index.xml
```

