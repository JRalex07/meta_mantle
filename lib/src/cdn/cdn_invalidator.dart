import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result summary of a CDN cache purge operation.
class CdnPurgeResult {
  const CdnPurgeResult({
    required this.success,
    required this.provider,
    required this.purgedCount,
    this.invalidationId,
    this.errorMessage,
  });

  final bool success;
  final String provider;
  final int purgedCount;
  final String? invalidationId;
  final String? errorMessage;
}

/// Abstract contract for programmatic CDN cache invalidation.
abstract interface class CdnInvalidator {
  /// Purges specific URLs from the CDN edge cache.
  Future<CdnPurgeResult> purgeUrls(List<String> urls);

  /// Purges cached representations associated with surrogate or cache tags.
  Future<CdnPurgeResult> purgeTags(List<String> tags);

  /// Flushes the entire CDN zone or distribution cache.
  Future<CdnPurgeResult> purgeAll();
}

/// In-memory CDN invalidator used for unit tests, local development, and CI environments.
class MemoryCdnInvalidator implements CdnInvalidator {
  final List<String> purgedUrls = [];
  final List<String> purgedTags = [];
  bool purgedAllCalled = false;

  @override
  Future<CdnPurgeResult> purgeUrls(List<String> urls) async {
    purgedUrls.addAll(urls);
    return CdnPurgeResult(
      success: true,
      provider: 'memory',
      purgedCount: urls.length,
      invalidationId: 'mem-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<CdnPurgeResult> purgeTags(List<String> tags) async {
    purgedTags.addAll(tags);
    return CdnPurgeResult(
      success: true,
      provider: 'memory',
      purgedCount: tags.length,
      invalidationId: 'mem-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<CdnPurgeResult> purgeAll() async {
    purgedAllCalled = true;
    return CdnPurgeResult(
      success: true,
      provider: 'memory',
      purgedCount: -1,
      invalidationId: 'mem-all',
    );
  }

  void reset() {
    purgedUrls.clear;
    purgedTags.clear();
    purgedAllCalled = false;
  }
}

/// Cloudflare v4 Cache Purge API adapter.
class CloudflareCdnInvalidator implements CdnInvalidator {
  CloudflareCdnInvalidator({
    required this.zoneId,
    required this.apiToken,
    http.Client? httpClient,
  }) : client = httpClient ?? http.Client();

  final String zoneId;
  final String apiToken;
  final http.Client client;

  @override
  Future<CdnPurgeResult> purgeUrls(List<String> urls) async {
    if (urls.isEmpty) {
      return const CdnPurgeResult(
        success: true,
        provider: 'cloudflare',
        purgedCount: 0,
      );
    }
    return _callCloudflare({'files': urls}, urls.length);
  }

  @override
  Future<CdnPurgeResult> purgeTags(List<String> tags) async {
    if (tags.isEmpty) {
      return const CdnPurgeResult(
        success: true,
        provider: 'cloudflare',
        purgedCount: 0,
      );
    }
    return _callCloudflare({'tags': tags}, tags.length);
  }

  @override
  Future<CdnPurgeResult> purgeAll() async {
    return _callCloudflare({'purge_everything': true}, 1);
  }

  Future<CdnPurgeResult> _callCloudflare(
    Map<String, dynamic> body,
    int count,
  ) async {
    final endpoint = Uri.parse(
      'https://api.cloudflare.com/client/v4/zones/$zoneId/purge_cache',
    );
    try {
      final res = await client.post(
        endpoint,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final jsonRes = json.decode(res.body) as Map<String, dynamic>;
      final success =
          res.statusCode >= 200 &&
          res.statusCode < 300 &&
          jsonRes['success'] == true;
      final resultId = jsonRes['result'] is Map
          ? jsonRes['result']['id']
          : null;

      return CdnPurgeResult(
        success: success,
        provider: 'cloudflare',
        purgedCount: success ? count : 0,
        invalidationId: resultId?.toString(),
        errorMessage: success
            ? null
            : 'HTTP ${res.statusCode}: ${json.encode(jsonRes['errors'])}',
      );
    } catch (e) {
      return CdnPurgeResult(
        success: false,
        provider: 'cloudflare',
        purgedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Unsupported placeholder for AWS CloudFront invalidation.
///
/// This package does not currently implement AWS Signature Version 4, so this
/// adapter deliberately reports failure instead of simulating an invalidation.
@Deprecated(
  'CloudFront invalidation is unsupported; use a real AWS SDK adapter.',
)
class CloudFrontCdnInvalidator implements CdnInvalidator {
  CloudFrontCdnInvalidator({
    required this.distributionId,
    this.callerReferencePrefix = 'meta_mantle',
    http.Client? httpClient,
  }) : client = httpClient ?? http.Client();

  final String distributionId;
  final String callerReferencePrefix;
  final http.Client client;

  @override
  Future<CdnPurgeResult> purgeUrls(List<String> urls) async {
    return _unsupported();
  }

  @override
  Future<CdnPurgeResult> purgeTags(List<String> tags) async {
    return _unsupported();
  }

  @override
  Future<CdnPurgeResult> purgeAll() async {
    return _unsupported();
  }

  CdnPurgeResult _unsupported() => const CdnPurgeResult(
    success: false,
    provider: 'cloudfront',
    purgedCount: 0,
    errorMessage: 'CloudFront invalidation is unsupported: AWS authentication and API calls are not implemented.',
  );
}

/// Nginx / Fastly reverse proxy cache purge adapter via HTTP PURGE.
class NginxProxyInvalidator implements CdnInvalidator {
  NginxProxyInvalidator({required this.proxyBaseUrl, http.Client? httpClient})
    : client = httpClient ?? http.Client();

  final String proxyBaseUrl;
  final http.Client client;

  @override
  Future<CdnPurgeResult> purgeUrls(List<String> urls) async {
    var successCount = 0;
    for (final url in urls) {
      try {
        final path = Uri.parse(url).path;
        final purgeUri = Uri.parse('$proxyBaseUrl$path');
        final req = http.Request('PURGE', purgeUri);
        final res = await client.send(req);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          successCount++;
        }
      } catch (_) {}
    }
    return CdnPurgeResult(
      success: successCount == urls.length,
      provider: 'nginx',
      purgedCount: successCount,
    );
  }

  @override
  Future<CdnPurgeResult> purgeTags(List<String> tags) async {
    return CdnPurgeResult(
      success: false,
      provider: 'nginx',
      purgedCount: 0,
      errorMessage: 'Nginx standard proxy_cache does not support surrogate tag purges natively.',
    );
  }

  @override
  Future<CdnPurgeResult> purgeAll() async {
    return purgeUrls(['/*']);
  }
}
