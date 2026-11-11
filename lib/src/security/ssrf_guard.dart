import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Security guard that protects outbound HTTP requests (URL inspector, crawler preview)
/// against Server-Side Request Forgery (SSRF), internal network scanning, and cloud metadata access.
class SsrfGuard {
  const SsrfGuard({
    this.allowedHosts = const {},
    this.allowLocalhostInDev = false,
    this.resolver = _systemResolver,
  });

  /// Optional strict hostname allowlist.
  final Set<String> allowedHosts;

  /// Whether localhost/loopback is permitted for local development inspection.
  /// This opt-in permits loopback only; private, link-local and special-purpose
  /// ranges remain blocked.
  final bool allowLocalhostInDev;

  /// Resolver hook for deterministic tests and controlled server environments.
  /// Every returned address is checked; an empty or mixed unsafe result fails closed.
  final Future<List<InternetAddress>> Function(String host) resolver;

  static Future<List<InternetAddress>> _systemResolver(String host) =>
      InternetAddress.lookup(host);

  /// Creates an [http.Client] that pins every socket connection directly to an
  /// IP address that was validated against SSRF rules, preventing DNS rebinding.
  http.Client createPinnedClient({
    Duration connectionTimeout = const Duration(seconds: 10),
  }) {
    final io = HttpClient();
    io.findProxy = (_) => 'DIRECT';
    io.connectionTimeout = connectionTimeout;
    io.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null || proxyPort != null) {
        throw const SecurityException(
            'Outbound proxy connections are disabled for SSRF protection.');
      }
      final candidates = await resolveAndValidate(uri);
      return Socket.startConnect(candidates.first, uri.port);
    };
    return IOClient(io);
  }

  /// Validates [uri] against SSRF boundaries before making any network connection.
  /// Throws [SecurityException] if the target violates security constraints.
  Future<void> validateUri(Uri uri) async {
    await resolveAndValidate(uri);
  }

  /// Resolves [uri] and returns only after every candidate address passes policy.
  /// A pinned socket transport must connect directly to one of these returned
  /// addresses instead of resolving the hostname again.
  Future<List<InternetAddress>> resolveAndValidate(Uri uri) async {
    // 1. Protocol validation
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw SecurityException(
          'Disallowed protocol: "$scheme". Only HTTP and HTTPS are permitted.');
    }

    if (uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const SecurityException(
          'Target URL must not contain user info or a fragment.');
    }
    final host = uri.host.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.isEmpty) {
      throw const SecurityException('Target URL host is missing.');
    }

    // 2. Strict cloud metadata host check
    if (host == '169.254.169.254' ||
        host == 'metadata.google.internal' ||
        host.endsWith('.metadata.google.internal')) {
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
      final literal = InternetAddress.tryParse(host);
      final addresses = literal == null ? await resolver(host) : [literal];
      if (addresses.isEmpty) {
        throw SecurityException('Unable to resolve host: $host');
      }

      for (final addr in addresses) {
        if (addr.isLoopback && !allowLocalhostInDev) {
          throw SecurityException(
              'Target resolves to a loopback address: ${addr.address}');
        }

        if (addr.isLinkLocal) {
          throw SecurityException(
              'Target resolves to a link-local address: ${addr.address}');
        }

        if (_isForbiddenAddress(addr) &&
            !(allowLocalhostInDev && addr.isLoopback)) {
          throw SecurityException(
              'Target resolves to a private network address: ${addr.address}');
        }
      }
      return List.unmodifiable(addresses);
    } on SocketException {
      throw SecurityException('DNS resolution failed for "$host".');
    }
  }

  bool _isForbiddenAddress(InternetAddress address) {
    if (address.type == InternetAddressType.IPv6 &&
        address.address.contains('%')) {
      return true;
    }
    if (address.isMulticast) return true;
    if (address.type == InternetAddressType.IPv4) {
      final parts = address.rawAddress;
      if (parts.every((byte) => byte == 0) ||
          parts[0] == 0 ||
          parts[0] == 10 ||
          parts[0] >= 224 ||
          (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 192 &&
              (parts[1] == 0 || parts[1] == 168 || parts[1] == 2)) ||
          (parts[0] == 192 && parts[1] == 88 && parts[2] == 99) ||
          (parts[0] == 198 &&
              (parts[1] == 18 ||
                  parts[1] == 19 ||
                  parts[1] == 51 && parts[2] == 100)) ||
          (parts[0] == 203 && parts[1] == 0 && parts[2] == 113)) {
        return true;
      }
    } else if (address.type == InternetAddressType.IPv6) {
      // IPv4-mapped IPv6 addresses must inherit the IPv4 private-range checks.
      final raw = address.rawAddress;
      final isIpv4Mapped = raw.take(10).every((byte) => byte == 0) &&
          raw[10] == 0xff &&
          raw[11] == 0xff;
      if (isIpv4Mapped) {
        final ipv4 = raw.sublist(12);
        return ipv4[0] == 0 ||
            ipv4[0] == 10 ||
            ipv4[0] == 127 ||
            ipv4[0] >= 224 ||
            (ipv4[0] == 100 && ipv4[1] >= 64 && ipv4[1] <= 127) ||
            (ipv4[0] == 172 && ipv4[1] >= 16 && ipv4[1] <= 31) ||
            (ipv4[0] == 192 && ipv4[1] == 168) ||
            (ipv4[0] == 169 && ipv4[1] == 254) ||
            (ipv4[0] == 192 &&
                (ipv4[1] == 0 || ipv4[1] == 2 || ipv4[1] == 168)) ||
            (ipv4[0] == 192 && ipv4[1] == 88 && ipv4[2] == 99) ||
            (ipv4[0] == 198 &&
                (ipv4[1] == 18 ||
                    ipv4[1] == 19 ||
                    ipv4[1] == 51 && ipv4[2] == 100)) ||
            (ipv4[0] == 203 && ipv4[1] == 0 && ipv4[2] == 113);
      }
      if (raw.every((byte) => byte == 0) || raw[0] == 0xff) return true;
      if ((raw[0] & 0xfe) == 0xfc) return true;
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true;
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0xc0) return true;
      if (raw[0] == 0x20 &&
          raw[1] == 0x01 &&
          raw[2] == 0x0d &&
          raw[3] == 0xb8) {
        return true;
      }
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
