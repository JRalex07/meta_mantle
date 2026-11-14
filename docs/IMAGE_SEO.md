# MetaMantle Image SEO & Core Web Vitals Subsystem

Images often represent the largest byte payload on web pages and are the primary driver of **Cumulative Layout Shift (CLS)** and **Largest Contentful Paint (LCP)** regressions.

MetaMantle's `ImageSeoAnalyzer` provides automated audit capabilities and Google Image XML sitemap generation.

---

## Key Image Optimization Rules

1. **Explicit Dimensions (CLS Prevention)**:
   Every `<img>` element must declare integer `width` and `height` attributes matching its natural aspect ratio. This allows the browser to reserve layout space before downloading pixels:
   ```html
   <img src="/hero.webp" width="1200" height="600" alt="Hero banner" />
   ```

2. **Alt Text Accessibility**:
   Every visual image must supply meaningful, concise `alt` text for screen readers and search crawlers. Decorative images should declare `alt=""` and `aria-hidden="true"`.

3. **Native Lazy Loading**:
   Images positioned below the initial viewport fold should specify `loading="lazy"`:
   ```html
   <img src="/product.avif" width="300" height="300" alt="Product thumbnail" loading="lazy" />
   ```

4. **Next-Generation Formats**:
   MetaMantle validates modern image formats: **WebP**, **AVIF**, and **SVG**, issuing warnings when legacy PNG or JPEG images are served without compression.

---

## Google Image XML Sitemap Generation

Search engines discover images embedded in JavaScript frameworks more reliably when indexed in dedicated image sitemaps.

Generate Google Image XML sitemaps using `ImageSeoAnalyzer`:

```dart
final analyzer = const ImageSeoAnalyzer();

final sitemap = analyzer.generateImageSitemap({
  'https://example.com/': [
    const ImageFinding(
      src: 'https://example.com/banner.webp',
      alt: 'Homepage Promotional Banner',
      hasAlt: true,
      hasDimensions: true,
      hasLazyLoading: false,
    ),
  ],
  'https://example.com/shop': [
    const ImageFinding(
      src: 'https://example.com/item.avif',
      alt: 'Running Shoes',
      hasAlt: true,
      hasDimensions: true,
      hasLazyLoading: true,
    ),
  ],
});
```

Produces:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
  <url>
    <loc>https://example.com/</loc>
    <image:image>
      <image:loc>https://example.com/banner.webp</image:loc>
      <image:title>Homepage Promotional Banner</image:title>
    </image:image>
  </url>
  <url>
    <loc>https://example.com/shop</loc>
    <image:image>
      <image:loc>https://example.com/item.avif</image:loc>
      <image:title>Running Shoes</image:title>
    </image:image>
  </url>
</urlset>
```
