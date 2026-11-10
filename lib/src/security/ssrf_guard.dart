import 'dart:async';
import 'dart:io';

/// Security guard that protects outbound HTTP requests (URL inspector, crawler preview)
/// against Server-Side Request Forgery (SSRF), internal network scanning, and cloud metadata access.
class SsrfGuard {
  const SsrfGuard({
    this.allowedHosts = const {},
    this.allowLocalhostInDev = false,
  });

  /// Optional strict hostname allowlist.
  final Set<String> allowedHosts;

  /// Whether localhost/loopback is permitted for local development inspection.
  final bool allowLocalhostInDev;

  /// Validates [uri] against SSRF boundaries before making any network connection.
  /// Throws [SecurityException] if the target violates security constraints.
  Future<void> validateUri(Uri uri) async {
    // 1. Protocol validation
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw SecurityException(
          'Disallowed protocol: "$scheme". Only HTTP and HTTPS are permitted.');
    }

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) {
      throw SecurityException('Target URL host is missing.');
    }

    // 2. Strict cloud metadata host check
    if (host == '169.254.169.254' ||
        host == 'metadata.google.internal' ||
        host.contains('metadata')) {
      throw SecurityException(
          'Access to cloud metadata endpoints is strictly blocked: $host');
    }

    // 3. Hostname allowlist check
    if (allowedHosts.isNotEmpty && !allowedHosts.contains(host)) {
      throw SecurityException(
          'Host "$host" is not present in the allowed outbound host whitelist.');
    }

    // 4. Resolve IP addresses and inspect against private ranges
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        throw SecurityException('Unable to resolve host: $host');
      }

      for (final addr in addresses) {
        if (!allowLocalhostInDev && addr.isLoopback) {
          throw SecurityException(
              'Target resolves to a loopback address: ${addr.address}');
        }

        if (addr.isLinkLocal) {
          throw SecurityException(
              'Target resolves to a link-local address: ${addr.address}');
        }

        if (!allowLocalhostInDev && _isPrivateIp(addr)) {
          throw SecurityException(
              'Target resolves to a private network address: ${addr.address}');
        }
      }
    } on SocketException catch (e) {
      throw SecurityException(
          'DNS resolution failed for "$host": ${e.message}');
    }
  }

  bool _isPrivateIp(InternetAddress address) {
    if (address.type == InternetAddressType.IPv4) {
      final parts = address.rawAddress;
      // 10.0.0.0/8
      if (parts[0] == 10) return true;
      // 172.16.0.0/12
      if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
      // 192.168.0.0/16
      if (parts[0] == 192 && parts[1] == 168) return true;
      // 169.254.0.0/16 (Link local / Cloud metadata)
      if (parts[0] == 169 && parts[1] == 254) return true;
    } else if (address.type == InternetAddressType.IPv6) {
      // IPv6 Unique Local Address (fc00::/7) or Site Local (fec0::/10)
      final raw = address.rawAddress;
      if ((raw[0] & 0xfe) == 0xfc) return true;
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0xc0) return true;
    }
    return false;
  }
}

/// Thrown when an outbound request violates SSRF security boundaries.
class SecurityException implements Exception {
  const SecurityException(this.message);
  final String message;

  @override
  String toString() => 'SecurityException: $message';
}
