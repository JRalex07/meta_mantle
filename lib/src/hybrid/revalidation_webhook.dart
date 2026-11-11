import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../server/server_request.dart';
import '../server/server_response.dart';
import 'revalidation_scheduler.dart';

abstract interface class WebhookReplayStore {
  /// Atomically records [eventId] until [expiresAt]; false means it was seen.
  Future<bool> claim(String eventId, DateTime expiresAt, DateTime now);
  Future<void> release(String eventId);
}

/// Process-local replay guard for tests and single-process development.
class MemoryWebhookReplayStore implements WebhookReplayStore {
  final Map<String, DateTime> _events = {};

  @override
  Future<bool> claim(String eventId, DateTime expiresAt, DateTime now) async {
    _events.removeWhere((_, expiry) => !expiry.isAfter(now));
    if (_events.containsKey(eventId)) return false;
    _events[eventId] = expiresAt;
    return true;
  }

  @override
  Future<void> release(String eventId) async => _events.remove(eventId);
}

/// File-based replay guard for a single host and a filesystem with file locks.
class FileWebhookReplayStore implements WebhookReplayStore {
  FileWebhookReplayStore(Directory directory) : directory = directory.absolute;
  final Directory directory;

  @override
  Future<bool> claim(String eventId, DateTime expiresAt, DateTime now) =>
      _locked(() async {
        final file = _eventFile(eventId);
        if (await file.exists()) {
          try {
            final previous = DateTime.parse(await file.readAsString());
            if (previous.isAfter(now)) return false;
          } on FormatException {
            // Corrupt replay records fail closed.
            return false;
          }
          await file.delete();
        }
        await file.writeAsString(expiresAt.toUtc().toIso8601String(),
            flush: true);
        return true;
      });

  @override
  Future<void> release(String eventId) => _locked(() async {
        final file = _eventFile(eventId);
        if (await file.exists()) await file.delete();
      });

  File _eventFile(String eventId) {
    final digest = sha256.convert(utf8.encode(eventId));
    return File('${directory.path}${Platform.pathSeparator}$digest.replay');
  }

  Future<T> _locked<T>(Future<T> Function() operation) async {
    await directory.create(recursive: true);
    final lockFile = File('${directory.path}${Platform.pathSeparator}.lock');
    final handle = await lockFile.open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    try {
      return await operation();
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }
}

/// Simple per-process fixed-window limiter. Put a trusted client address in
/// [ServerRequest.clientIp] when the application sits behind a proxy.
class InMemoryWebhookRateLimiter {
  InMemoryWebhookRateLimiter({
    this.maxRequests = 60,
    this.window = const Duration(minutes: 1),
    this.maxTrackedKeys = 4096,
  }) {
    if (maxRequests < 1 || window <= Duration.zero || maxTrackedKeys < 1) {
      throw ArgumentError('Invalid webhook rate limit.');
    }
  }

  final int maxRequests;
  final Duration window;
  final int maxTrackedKeys;
  final Map<String, (DateTime start, int count)> _windows = {};

  bool allow(String key, DateTime now) {
    _windows.removeWhere((_, entry) => !now.isBefore(entry.$1.add(window)));
    final current = _windows[key];
    if (current == null || !now.isBefore(current.$1.add(window))) {
      if (current == null && _windows.length >= maxTrackedKeys) return false;
      _windows[key] = (now, 1);
      return true;
    }
    if (current.$2 >= maxRequests) return false;
    _windows[key] = (current.$1, current.$2 + 1);
    return true;
  }
}

/// Signed webhook endpoint that schedules revalidation against the configured
/// site's dependency index. The payload never supplies HTML or database data.
class RevalidationWebhookHandler {
  RevalidationWebhookHandler({
    required this.scheduler,
    required this.replayStore,
    required this.tenantId,
    required List<int> secret,
    this.clock,
    this.maxClockSkew = const Duration(minutes: 5),
    this.maxBodyBytes = 16384,
    InMemoryWebhookRateLimiter? rateLimiter,
  })  : secret = List.unmodifiable(secret),
        rateLimiter = rateLimiter ?? InMemoryWebhookRateLimiter() {
    if (secret.length < 32) {
      throw ArgumentError('Webhook secrets must contain at least 32 bytes.');
    }
    if (tenantId.trim().isEmpty ||
        maxClockSkew <= Duration.zero ||
        maxBodyBytes < 1) {
      throw ArgumentError('Invalid webhook handler configuration.');
    }
  }

  final HybridRevalidationScheduler scheduler;
  final WebhookReplayStore replayStore;
  final String tenantId;
  final List<int> secret;
  final DateTime Function()? clock;
  final Duration maxClockSkew;
  final int maxBodyBytes;
  final InMemoryWebhookRateLimiter rateLimiter;

  Future<ServerResponse> handle(ServerRequest request) async {
    if (request.method != 'POST') {
      return _json(405, {'error': 'method_not_allowed'}, {'Allow': 'POST'});
    }
    final now = (clock?.call() ?? DateTime.now()).toUtc();
    if (request.bodyBytes.length > maxBodyBytes) {
      return _json(413, {'error': 'payload_too_large'});
    }
    final timestamp = request.header('x-metamantle-timestamp');
    final eventId = request.header('x-metamantle-event-id');
    final signature = request.header('x-metamantle-signature');
    final seconds = int.tryParse(timestamp ?? '');
    if (timestamp == null ||
        seconds == null ||
        eventId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(eventId) ||
        signature == null) {
      return _json(401, {'error': 'invalid_signature_headers'});
    }
    final signedAt =
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (now.difference(signedAt).abs() > maxClockSkew) {
      return _json(401, {'error': 'expired_signature'});
    }
    late final String body;
    try {
      body = request.bodyText;
    } on FormatException {
      return _json(400, {'error': 'invalid_payload'});
    }
    final canonical = '$timestamp\n$eventId\n$tenantId\n$body';
    final expected = Hmac(sha256, secret).convert(utf8.encode(canonical)).bytes;
    final suppliedHex =
        signature.startsWith('sha256=') ? signature.substring(7) : signature;
    final supplied = _decodeHex(suppliedHex);
    if (supplied == null || !_constantTimeEquals(expected, supplied)) {
      return _json(401, {'error': 'invalid_signature'});
    }
    if (!rateLimiter.allow(tenantId, now)) {
      return _json(429, {'error': 'rate_limited'});
    }

    Map<String, Object?> payload;
    try {
      payload = Map<String, Object?>.from(jsonDecode(body) as Map);
    } on Object {
      return _json(400, {'error': 'invalid_payload'});
    }
    if (payload['tenantId'] != tenantId) {
      return _json(403, {'error': 'tenant_mismatch'});
    }
    final path = payload['path'];
    final tag = payload['tag'];
    final routeId = payload['routeId'];
    if ([path, tag, routeId].where((value) => value != null).length != 1 ||
        (path != null && path is! String) ||
        (tag != null && tag is! String) ||
        (routeId != null && routeId is! String)) {
      return _json(400, {'error': 'invalid_selector'});
    }

    final replayExpires = now.add(maxClockSkew);
    final claimed = await replayStore.claim(eventId, replayExpires, now);
    if (!claimed) return _json(409, {'error': 'replayed_event'});
    try {
      final report = path is String
          ? await scheduler.revalidatePath(path, eventId: eventId)
          : tag is String
              ? await scheduler.revalidateTag(tag, eventId: eventId)
              : await scheduler.revalidateRoute(routeId as String,
                  eventId: eventId);
      return _json(
          202, {'jobIds': report.jobIds, 'scheduled': report.jobs.length});
    } on FormatException {
      await replayStore.release(eventId);
      return _json(400, {'error': 'invalid_selector'});
    } on Object {
      await replayStore.release(eventId);
      return _json(500, {'error': 'revalidation_unavailable'});
    }
  }

  /// Shelf handler that caps streamed request bodies before buffering them.
  shelf.Handler createShelfHandler() => (shelf.Request request) async {
        final bytes = <int>[];
        await for (final chunk in request.read()) {
          if (bytes.length + chunk.length > maxBodyBytes) {
            return _toShelfResponse(_json(413, {'error': 'payload_too_large'}));
          }
          bytes.addAll(chunk);
        }
        final response = await handle(ServerRequest(
          method: request.method,
          uri: request.requestedUri,
          headers: request.headers,
          bodyBytes: bytes,
        ));
        return _toShelfResponse(response);
      };

  shelf.Response _toShelfResponse(ServerResponse response) => shelf.Response(
        response.statusCode,
        body: response.bodyBytes,
        headers: response.headers,
      );
}

List<int>? _decodeHex(String value) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) return null;
  return [
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16)
  ];
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  var difference = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    difference |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
  }
  return difference == 0;
}

ServerResponse _json(int status, Map<String, Object?> value,
        [Map<String, String> headers = const {}]) =>
    ServerResponse(
      statusCode: status,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
        ...headers,
      },
      body: jsonEncode(value),
    );
