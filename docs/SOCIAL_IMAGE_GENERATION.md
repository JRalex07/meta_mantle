# MetaMantle Social Image Generation & Open Graph Architecture

High-converting social media links require reliable Open Graph (`og:image`) and Twitter Card (`twitter:image`) metadata with precise dimensions, aspect ratios, and secure fallback cascades.

---

## 1. Open Graph & Twitter Card Specifications

| Platform | Recommended Aspect Ratio | Optimal Resolution | Minimum Dimensions |
| :--- | :--- | :--- | :--- |
| **Twitter / X** (`summary_large_image`) | 2:1 or 1.91:1 | 1200 x 628 px | 300 x 157 px |
| **LinkedIn & Facebook** | 1.91:1 | 1200 x 630 px | 200 x 200 px |
| **Twitter Small Summary** (`summary`) | 1:1 (Square) | 400 x 400 px | 144 x 144 px |

---

## 2. Multi-Tier Social Image Fallback Cascade

In large applications, not every page has a unique custom graphic. MetaMantle's `SeoPolicyResolver` cascades social images through configured policy tiers:

$$\text{Page Image} \longrightarrow \text{Section Image} \longrightarrow \text{Tenant/Brand Image} \longrightarrow \text{Global Default Image}$$

```dart
final globalPolicy = SeoPolicy(
  tier: PolicyTier.global,
  defaultOpenGraphImage: 'https://example.com/assets/default-og.png',
);

final sectionPolicy = SeoPolicy(
  tier: PolicyTier.section,
  defaultOpenGraphImage: 'https://example.com/assets/docs-og.png',
);

final pagePolicy = SeoPolicy(
  tier: PolicyTier.page,
  defaultOpenGraphImage: 'https://example.com/assets/deep-dive-diagram.png',
);

// SeoPolicyResolver resolves to the most specific image available
final resolved = resolver.resolve(tiers: [globalPolicy, sectionPolicy, pagePolicy]);
```

---

## 3. Dynamic Social Media Image Generation Patterns

For dynamic pages (e.g. blog posts, e-commerce products, user profiles), social images can be generated dynamically using signed image CDN URLs or serverless rendering functions:

```dart
String buildDynamicOgImage({
  required String title,
  required String subtitle,
  required String author,
}) {
  final encodedTitle = Uri.encodeComponent(title);
  final encodedSubtitle = Uri.encodeComponent(subtitle);
  final encodedAuthor = Uri.encodeComponent(author);

  return 'https://og.metamantle.dev/api/card'
      '?title=$encodedTitle'
      '&subtitle=$encodedSubtitle'
      '&author=$encodedAuthor';
}
```

```dart
final metadata = WebMetadata(
  title: post.title,
  openGraph: OpenGraph(
    title: post.title,
    description: post.summary,
    image: buildDynamicOgImage(
      title: post.title,
      subtitle: post.category,
      author: post.author,
    ),
    imageWidth: 1200,
    imageHeight: 630,
    imageType: 'image/png',
  ),
  twitter: const TwitterCard(
    card: TwitterCardType.summaryLargeImage,
  ),
);
```

