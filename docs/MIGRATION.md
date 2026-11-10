# Migration Guide

Learn how to migrate to MetaMantle from React Helmet, Next.js Metadata, or vanilla Flutter `web/index.html`.

---

## 1. Migrating from React Helmet

In React Helmet:
```jsx
<Helmet>
  <title>About Us | My Store</title>
  <meta name="description" content="About our store" />
  <link rel="canonical" href="https://example.com/about" />
</Helmet>
```

In MetaMantle:
```dart
WebHead(
  metadata: const WebMetadata(
    title: 'About Us',
    description: 'About our store',
    canonical: 'https://example.com/about',
  ),
  child: const AboutPageContent(),
)
```
*Note:* If you configured `titleTemplate: '%s | My Store'` during `MetaMantle.initialize()`, MetaMantle automatically appends `| My Store`.

---

## 2. Migrating from Next.js Metadata

In Next.js:
```typescript
export const metadata: Metadata = {
  title: 'Organic Basmati Rice',
  description: 'Pure aged long-grain rice.',
  openGraph: {
    title: 'Organic Basmati Rice',
    images: ['/images/rice.jpg'],
  },
};
```

In MetaMantle SSR:
```dart
MetaRoute<Product>(
  pattern: '/products/:slug',
  dataProvider: productProvider,
  metadataBuilder: (product, context) => WebMetadata(
    title: product.name,
    description: product.summary,
    openGraph: OpenGraph(
      title: product.name,
      image: product.imageUrl,
    ),
  ),
  htmlBuilder: (product, context) => [
    H.h1(product.name),
    H.p(product.summary),
  ],
)
```

---

## 3. Migrating from Vanilla Flutter `web/index.html`

Before MetaMantle, developers had to hardcode single generic metadata tags in `web/index.html`:
```html
<title>My Flutter App</title>
<meta name="description" content="A Flutter Web application" />
```
This resulted in identical titles and descriptions across every route on the site.

With MetaMantle:
1. Retain standard fallback defaults in `web/index.html`.
2. Configure `meta_mantle.config.json` for static pre-rendering, or run `MetaMantleServerEngine` for dynamic SSR.
3. Every page now receives its own unique, validated, crawler-ready `<head>` tags and semantic body content.

