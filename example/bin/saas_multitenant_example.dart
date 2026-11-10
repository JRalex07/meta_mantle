// ignore_for_file: avoid_print
import 'package:meta_mantle/meta_mantle_server.dart';

void main() async {
  print('========================================================');
  print(' MetaMantle SaaS Multi-Tenancy & Host Security Example');
  print('========================================================');

  const tenantAcme = TenantContext(
    tenantId: 'acme-corp',
    name: 'Acme Corporation',
    primaryDomain: 'acme.tenant-portal.dev',
    customDomains: ['portal.acme-corp.com'],
    defaultLocale: 'en_US',
    defaultCurrency: 'USD',
  );

  const tenantGlobex = TenantContext(
    tenantId: 'globex-inc',
    name: 'Globex Industries',
    primaryDomain: 'globex.tenant-portal.dev',
    customDomains: ['app.custom-domain.com'],
    defaultLocale: 'en_GB',
    defaultCurrency: 'GBP',
  );

  // 1. Host Validation (Host Header Injection Guard)
  const hostValidator = TenantHostValidator(
    tenants: [tenantAcme, tenantGlobex],
    allowedRootDomains: ['tenant-portal.dev'],
  );

  print('[Testing Host Header Injection & Resolution]');
  final testHosts = [
    'acme.tenant-portal.dev',
    'app.custom-domain.com',
    'attacker-controlled.com', // Evil host injection
    'sub.attacker-controlled.com',
  ];

  for (final host in testHosts) {
    try {
      final tenant = hostValidator.validate(host);
      print('  Host: $host -> Tenant: ${tenant.tenantId} (Authorized: TRUE)');
    } catch (_) {
      print('  Host: $host -> REJECTED (Host header injection blocked)');
    }
  }

  // 2. Tenant-Isolated Cache Partitioner
  final cacheStore = MemoryCacheStore(maxEntries: 1000);
  final partitioner = TenantCachePartitioner(cacheStore);

  final acmeCacheKey = partitioner.buildKey(
    tenantId: tenantAcme.tenantId,
    host: tenantAcme.primaryDomain,
    path: '/dashboard',
    locale: tenantAcme.defaultLocale,
    currency: tenantAcme.defaultCurrency,
  );

  final globexCacheKey = partitioner.buildKey(
    tenantId: tenantGlobex.tenantId,
    host: tenantGlobex.primaryDomain,
    path: '/dashboard',
    locale: tenantGlobex.defaultLocale,
    currency: tenantGlobex.defaultCurrency,
  );

  print('\n[Tenant Cache Key Isolation]');
  print('  Acme Key:   $acmeCacheKey');
  print('  Globex Key: $globexCacheKey');
  print('  Isolated:   ${acmeCacheKey != globexCacheKey}');

  // Cache entries under tenant tags
  await cacheStore.put(
    acmeCacheKey,
    CacheEntry(
      html: '<html><body><h1>Acme Corp Dashboard</h1></body></html>',
      metadata: const WebMetadata(title: 'Acme Corp Dashboard'),
      createdAt: DateTime.now().toUtc(),
      ttl: const Duration(hours: 1),
      tags: partitioner.tenantTags(tenantAcme.tenantId, ['dashboard']),
    ),
  );

  await cacheStore.put(
    globexCacheKey,
    CacheEntry(
      html: '<html><body><h1>Globex Corp Dashboard</h1></body></html>',
      metadata: const WebMetadata(title: 'Globex Corp Dashboard'),
      createdAt: DateTime.now().toUtc(),
      ttl: const Duration(hours: 1),
      tags: partitioner.tenantTags(tenantGlobex.tenantId, ['dashboard']),
    ),
  );

  print('\n[Cache Invalidation Targeting Single Tenant]');
  await partitioner.invalidateTenant(tenantAcme.tenantId);
  print('  Invalidated entries for Acme Corp.');
  print(
      '  Acme entry in cache:   ${await cacheStore.get(acmeCacheKey) != null}');
  print(
      '  Globex entry in cache: ${await cacheStore.get(globexCacheKey) != null}');
  print('========================================================');
}
