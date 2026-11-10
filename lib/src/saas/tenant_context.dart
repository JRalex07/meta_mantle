/// Contextual representation of a tenant in a multi-tenant or white-label application.
class TenantContext {
  const TenantContext({
    required this.tenantId,
    required this.name,
    required this.primaryDomain,
    this.customDomains = const [],
    this.defaultLocale = 'en',
    this.defaultCurrency = 'USD',
    this.enforceHttps = true,
    this.customSettings = const {},
  });

  final String tenantId;
  final String name;
  final String primaryDomain;
  final List<String> customDomains;
  final String defaultLocale;
  final String defaultCurrency;
  final bool enforceHttps;
  final Map<String, dynamic> customSettings;

  /// Returns all authorized hostnames for this tenant.
  Set<String> get allAuthorizedHosts => {
        primaryDomain.toLowerCase(),
        for (final d in customDomains) d.toLowerCase(),
      };
}

/// Security guard that validates incoming HTTP Host headers against trusted tenant domains.
class TenantHostValidator {
  const TenantHostValidator({
    required this.tenants,
    this.allowedRootDomains = const [],
  });

  final List<TenantContext> tenants;
  final List<String> allowedRootDomains;

  /// Validates [hostHeader] against registered tenants.
  /// Returns the matched [TenantContext] if authorized, or throws [SecurityException] if invalid.
  TenantContext validate(String hostHeader) {
    final cleanHost = hostHeader.split(':').first.trim().toLowerCase();

    // Check against tenant custom domains & primary domains
    for (final tenant in tenants) {
      if (tenant.allAuthorizedHosts.contains(cleanHost)) {
        return tenant;
      }
    }

    // Check if host matches authorized root wildcard domain (e.g. *.platform.com)
    for (final rootDomain in allowedRootDomains) {
      final cleanRoot = rootDomain.toLowerCase();
      if (cleanHost == cleanRoot || cleanHost.endsWith('.$cleanRoot')) {
        final subdomain =
            cleanHost.substring(0, cleanHost.length - cleanRoot.length - 1);
        final matched =
            tenants.where((t) => t.tenantId == subdomain).firstOrNull;
        if (matched != null) return matched;
      }
    }

    throw HostValidationException(
      'Unauthorized or unregistered Host header: "$hostHeader". Access denied to prevent host injection.',
    );
  }
}

class HostValidationException implements Exception {
  const HostValidationException(this.message);
  final String message;

  @override
  String toString() => 'HostValidationException: $message';
}
