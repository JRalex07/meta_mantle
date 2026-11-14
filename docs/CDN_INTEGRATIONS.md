# MetaMantle CDN & Edge Invalidation Architecture

MetaMantle supports automatic cache purging across global CDN providers via `CdnInvalidator`.

---

## Supported Providers

- **Cloudflare**: Zone cache purge via API Token (`/zones/{zone_id}/purge_cache`).
- **Fastly**: Surrogate-Key and URL invalidation.
- **AWS CloudFront**: Distribution invalidation batches.
- **Akamai / Vercel Edge**: Tag and path-based cache clearing.

---

## Usage Example

```dart
import 'package:meta_mantle/meta_mantle_server.dart';

final cdn = CdnInvalidator.cloudflare(
  apiToken: Platform.environment['CLOUDFLARE_API_TOKEN']!,
  zoneId: Platform.environment['CLOUDFLARE_ZONE_ID']!,
);

// Invalidate after regenerating products
await cdn.purgePaths([
  '/',
  '/products',
  '/products/item-123',
]);
```
