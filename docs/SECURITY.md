# Security Architecture

This document details the security principles, data sanitization, URL validation, and filesystem protections implemented in `meta_mantle`.

---

## 1. Context-Aware HTML Escaping

All metadata values injected into HTML elements (titles, descriptions, Open Graph cards, Twitter metadata, custom meta tags, and link tags) undergo entity escaping before insertion into the document.

The following characters are escaped when placed in HTML attributes:
- `&` -> `&amp;`
- `<` -> `&lt;`
- `>` -> `&gt;`
- `"` -> `&quot;`
- `'` -> `&#39;`

This prevents attribute breakout attacks (`" onmouseover="alert(1)`).

---

## 2. Structured Data (JSON-LD) Script Breakout Protection

A critical vulnerability in web applications injecting JSON-LD into `<script type="application/ld+json">` is script tag breakout:
```html
<script type="application/ld+json">{"name":"Product</script><script>alert(1)</script>"}</script>
```

`meta_mantle` neutralizes this vector by serializing all JSON-LD strings with Unicode escape sequences for sensitive characters:
- `<` is replaced with `\u003C`
- `>` is replaced with `\u003E`
- `&` is replaced with `\u0026`

Even if a malicious user provides a title containing `</script>`, the browser's HTML parser receives `\u003C/script\u003E` inside the JSON string, which the JavaScript runtime parses safely as string text without terminating the script block.

---

## 3. URL Validation & Dangerous Scheme Rejection

`meta_mantle` enforces strict URL validation in `MetadataRenderer`:
- Canonical URLs and alternate URLs must use `http`, `https`, or scheme-relative `//` origins.
- Dangerous URI schemes, including `javascript:`, `data:`, `vbscript:`, and `file:`, are rejected with a `FormatException`.
- Canonical URLs are restricted from containing fragments (`#`) or arbitrary query parameters (`?`) unless intentionally configured.

---

## 4. DOM Ownership and Cross-Widget Isolation

In runtime mode, `meta_mantle` uses an explicit DOM ownership model:
- Every managed element receives `data-mm-owner="meta_mantle"` and `data-mm-key="<stable-identity>"`.
- Existing third-party tags (Google Analytics, Google Tag Manager, custom fonts, Stripe JS) are never removed.
- If an existing tag is adopted by a scope, its original attribute snapshot is stored in memory and restored when the scope unmounts.

---

## 5. Path Traversal Mitigation in Static Generation

The static builder writes HTML files to disk based on configured route paths and data files. To prevent directory traversal attacks:
- Route paths are checked before writing to ensure they start with `/` and do not contain `..` or leading root escapes.
- Data files referenced in dynamic patterns (`dataFile`) must reside within the project directory; relative directory traversal above the configuration root is rejected.
