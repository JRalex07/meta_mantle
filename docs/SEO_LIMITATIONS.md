# SEO behavior and limitations

## Runtime metadata is not initial-response metadata

The runtime adapter changes `document.head` after Flutter starts. This is useful for browser tabs, client-side navigation, accessibility and crawlers that render JavaScript. It does not guarantee that social link-preview bots or other non-rendering clients will see those changes.

Use static route generation or server-side HTML delivery when metadata must exist in the first HTTP response.

## Metadata is not full content rendering

Flutter Web Head does not convert Flutter's widget tree or canvas output into semantic HTML. It can generate title, description, canonical, social tags, icons, alternate links and JSON-LD. A page whose important content exists only inside Flutter's rendered surface may still be less discoverable or accessible than an HTML-first page.

## Search engines are not uniform

Google documents a crawl, render and index pipeline for JavaScript pages and can render JavaScript, but rendering is a separate stage and may be delayed. Other crawlers and social preview systems may not execute JavaScript. Initial HTML is the safer common baseline for metadata.

## Canonical is a hint

A `rel="canonical"` annotation is a strong canonicalization signal, not an instruction that every search engine must obey. Keep canonical tags and sitemap URLs consistent. Do not include URL fragments. Avoid generating a self-canonical URL for pages that intentionally represent a duplicate or alternate version.

## Structured data

JSON-LD must describe content that is genuinely present and visible on the page. Valid JSON-LD does not guarantee a rich result. Google's feature-specific requirements can change; validate using Google's Rich Results Test and Search Console.

## No ranking guarantees

This package only produces metadata and static HTML files. It cannot guarantee crawling, indexing, ranking, rich results or link-preview appearance. Those outcomes depend on page content, server status, robots directives, site quality, crawl access and external platform behavior.
