# Multilingual SEO & Hreflang Validation

Managing international applications with localized versions (e.g., `en-US`, `es-ES`, `fr-FR`) requires strict bidirectional `hreflang` links.

---

## 1. Hreflang Tags

When rendering multilingual documents, MetaMantle generates `<link rel="alternate" hreflang="..." href="...">` elements for every locale alternative:

```html
<link rel="alternate" hreflang="en-US" href="https://example.com/en/products/rice/" />
<link rel="alternate" hreflang="es-ES" href="https://example.com/es/productos/arroz/" />
<link rel="alternate" hreflang="x-default" href="https://example.com/en/products/rice/" />
```

---

## 2. Reciprocal Validation (`HreflangValidator`)

A common mistake in international SEO is one-way `hreflang` linking. Google Search Console will flag errors if Page A links to Page B with `hreflang="es"`, but Page B does not link back to Page A with `hreflang="en"`.

MetaMantle's `HreflangValidator` (`lib/src/seo/hreflang_validator.dart`) analyzes route tables during builds:
```dart
final issues = HreflangValidator.validate(routeMap);
```

### Checks Performed:
- **Missing Reciprocal Links**: Detects routes that point to target locales without receiving a return pointer.
- **Missing `x-default`**: Warns when no fallback landing page is declared for unassigned languages.
- **Invalid BCP-47 Language Codes**: Flags non-standard language tags (e.g. `eng_USA` instead of `en-US`).

