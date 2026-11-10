# HTTP Caching & Conditional Requests

MetaMantle's SSR Engine natively supports HTTP/1.1 and HTTP/2 caching semantics.

---

## 1. Conditional Requests (304 Not Modified)

MetaMantle calculates cryptographic entity tags (ETags) and tracks `Last-Modified` timestamps for every rendered page.

### `If-None-Match`:
When a browser or CDN provides `If-None-Match`:
```http
GET /products/basmati-rice HTTP/1.1
Host: example.com
If-None-Match: "w/e3b0c44298fc1c149afbf4c8996fb924"
```
If the calculated ETag matches, MetaMantle responds immediately with:
```http
HTTP/1.1 304 Not Modified
ETag: "w/e3b0c44298fc1c149afbf4c8996fb924"
Cache-Control: public, max-age=900, stale-while-revalidate=3600
```
**Zero bytes of HTML body are transmitted across the network.**

### `If-Modified-Since`:
Similarly, if the page's `lastModified` timestamp is earlier than or equal to the client's `If-Modified-Since` header, the server returns `304 Not Modified`.

---

## 2. Standard Headers Emitted

For every SSR response, MetaMantle emits standard HTTP headers:
- `Content-Type: text/html; charset=utf-8`
- `ETag: ...`
- `Last-Modified: <RFC 1123 HTTP-Date>`
- `Cache-Control: public, max-age=..., stale-while-revalidate=...`
- `X-MetaMantle-Cache: HIT | MISS | STALE`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`

