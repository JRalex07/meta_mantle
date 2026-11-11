# Security Architecture

This document details the security principles, data sanitization, URL validation, SSRF mitigation, and filesystem protections implemented in `meta_mantle`.

## Reproducible secret scan

The CI workflow runs Gitleaks v8.30.1 against both checked-out Git history and current checkout files with redaction enabled. To run the same version locally with Docker:

```bash
docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 git --redact --no-banner --log-opts="--all" /repo
docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 dir --redact --no-banner /repo
```

The scan redacts detected secret values. Treat any finding as sensitive and do not share unredacted scanner output.

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

---

## 6. Server-Side Request Forgery (SSRF) Guard

In SSR and Crawler environments, resolving untrusted external URLs risks exposing internal private networks and cloud metadata services.

`SsrfGuard` (`lib/src/security/ssrf_guard.dart`) blocks loopback, private, link-local, unspecified, multicast, and selected reserved/special-purpose IPv4 and IPv6 ranges. It rejects mixed DNS answers if any returned address is forbidden, rejects empty/error answers, strips a final DNS dot before policy checks, blocks metadata names and IPs, and permits only HTTP(S) URLs without user-info or fragments.

`CrawlerInspector` uses a pinned-address `dart:io` transport by default. For each new connection it disables proxies, resolves the hostname again, validates every answer, and opens a socket directly to a checked address. It does not attempt an unchecked address fallback. Dart's `HttpClient` still receives the original URI, preserving its normal Host header and TLS hostname verification/SNI. Redirects are manual, limited to five by default (hard cap ten), loop checked, revalidated before each request, and HTTPS-to-HTTP downgrades are rejected. Response bodies are streamed with a 2 MiB default cap; per-hop timeout defaults to 10 seconds and total operation budget to 30 seconds.

Localhost access is **off by default**. Library users who intentionally inspect a local server can opt in with `ssrfGuard: const SsrfGuard(allowLocalhostInDev: true)`. This permits loopback addresses only; private and link-local networks remain blocked. Do not enable this option for untrusted URLs. Call `CrawlerInspector.close()` when finished to close its internally created client. A caller-supplied `http.Client` replaces the pinned default transport, so the caller is responsible for its proxy, DNS-pinning, and cancellation behavior; the guard still checks URLs before each request but cannot control an arbitrary custom client's socket implementation. DNS lookup itself is not cancellable through `InternetAddress.lookup`; a timed-out lookup may finish in the background, but no request is sent until validation succeeds. REST/GraphQL providers continue to validate DNS before requests but do not yet pin the connection address, so deployments using those providers should apply outbound network egress controls.

---

## 7. Strict HTML Sanitization (`HtmlSanitizer`)

When SSR routes render rich text articles or user-generated descriptions, `HtmlSanitizer` runs an allowlist filter:
- Drops active execution elements: `<script>`, `<iframe>`, `<object>`, `<embed>`, `<form>`, `<input>`, `<link>`, `<style>`.
- Drops all `on*` event handlers (`onload`, `onclick`, `onerror`).
- Drops `style` attributes to prevent CSS expression attacks.
- Strips dangerous URL schemes (`javascript:`, `vbscript:`, `data:`) from `href` and `src` attributes.

---

## 8. Open Redirect Defense (`RedirectManager`)

To prevent phishing and open-redirect vulnerabilities:
- Internal redirects must begin with `/` and not contain backslashes (`\`) or double slashes (`//`) that fool parser normalization.
- External redirects to third-party domains are blocked unless the destination domain is explicitly registered in the allowed domains list.
