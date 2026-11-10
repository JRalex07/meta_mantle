# Search Engine Optimization (SEO) Capabilities

MetaMantle manages all search engine optimization signals for Flutter Web applications.

---

## 1. Supported Head Tags & Metas

| Feature | Meta / Link Tag | Description |
|---|---|---|
| Page Title | `<title>` | Auto-resolves against `titleTemplate` and `defaultTitle`. |
| Meta Description | `<meta name="description">` | Snippet description used in SERPs. |
| Canonical URL | `<link rel="canonical">` | Normalizes duplicate URLs, protocol variants, and tracking query params. |
| Robots Directives | `<meta name="robots">` | Controls indexing, following, snippet size, and caching. |
| Keywords | `<meta name="keywords">` | Comma-separated topical keywords. |
| Author & Publisher | `<meta name="author">` | Content authorship credit. |
| Theme Color | `<meta name="theme-color">` | Customizes mobile browser status bar tint. |
| Mobile Viewport | `<meta name="viewport">` | Configures mobile viewport scaling. |
| Favicons | `<link rel="icon">`, `<link rel="apple-touch-icon">` | Site iconography across devices. |
| Charset | `<meta charset="utf-8">` | Document character encoding. |

---

## 2. Open Graph (Social Sharing)

MetaMantle renders Open Graph protocol tags required for rich preview cards across social networks (WhatsApp, LinkedIn, iMessage, Discord, Facebook):
- `og:title`, `og:description`, `og:url`
- `og:site_name`, `og:type` (`website`, `article`, `product`, `video`, etc.)
- `og:image`, `og:image:width`, `og:image:height`, `og:image:alt`
- `og:locale`, `og:locale:alternate`

---

## 3. Twitter Cards

Dedicated Twitter / X metadata:
- `twitter:card`: `summary`, `summary_large_image`, `app`, `player`.
- `twitter:site`: Site handle (`@MetaMantle`).
- `twitter:creator`: Content creator handle.
- `twitter:title`, `twitter:description`, `twitter:image`.

