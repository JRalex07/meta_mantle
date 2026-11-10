# MetaMantle SaaS, Multi-Tenancy & Host Security

SaaS platforms, white-label e-commerce stores, and enterprise portals host thousands of client workspaces across wildcard subdomains and custom apex domains. Multi-tenancy introduces critical security challenges around Host Header Injection and cross-tenant cache contamination.

---

## 1. Host Header Injection Guard (`TenantHostValidator`)

In reverse-proxy environments (Cloudflare, AWS ALB, Nginx), attackers can spoof the incoming HTTP `Host` header to poison password reset links, poison server caches, or hijack OAuth redirects.

`TenantHostValidator` provides zero-trust domain authorization:
- Matches incoming hosts strictly against registered tenant primary domains and custom domains.
- Safely validates wildcard root subdomains (e.g. `*.platform.dev`).
- Rejects unmapped, unrecognized, or spoofed host headers with `HostValidationException`.

```dart
const validator = TenantHostValidator(
  tenants: [
    TenantContext(
      tenantId: 'acme-corp',
      name: 'Acme Corporation',
      primaryDomain: 'acme.platform.dev',
      customDomains: ['portal.acme.com'],
    ),
  ],
  allowedRootDomains: ['platform.dev'],
);

// Resolves tenant context safely
final tenant = validator.validate(request.headers['host'] ?? '');
```

---

## 2. Multi-Tenant Cache Key Isolation (`TenantCachePartitioner`)

Serving Tenant B's branded content or private catalog to Tenant A's user is a catastrophic failure.

`TenantCachePartitioner` deterministically isolates cache entries:

$$\text{CacheKey} = \text{tenant}:\{\text{tenantId}\}:\text{host}:\{\text{host}\}:\text{loc}:\{\text{locale}\}:\text{cur}:\{\text{currency}\}:\text{path}:\{\text{path}\}?\{\text{sortedQuery}\}$$

```dart
final partitioner = TenantCachePartitioner(cacheStore);

final cacheKey = partitioner.buildKey(
  tenantId: tenant.tenantId,
  host: tenant.primaryDomain,
  path: request.path,
  locale: tenant.defaultLocale,
  currency: tenant.defaultCurrency,
);
```

---

## 3. Targeted Tenant Cache Purging

When Tenant A updates their brand logo, theme color, or product catalog, only Tenant A's cache entries should be evicted. Global cache purges waste server CPU and database bandwidth.

`TenantCachePartitioner` attaches namespaced semantic tags:

```dart
final tags = partitioner.tenantTags(tenant.tenantId, ['catalog', 'navigation']);
// ['tenant:acme-corp', 'tenant:acme-corp:catalog', 'tenant:acme-corp:navigation']

// When Tenant updates catalog:
await partitioner.invalidateTenant(tenant.tenantId);
// Only evicts entries for 'acme-corp' while leaving all other tenants untouched in memory!
```

