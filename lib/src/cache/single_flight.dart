import 'dart:async';

/// Abstract contract for distributed locking across multi-instance production clusters.
abstract interface class DistributedLockProvider {
  /// Attempts to acquire a distributed lock for [resource] with a lease [ttl].
  /// Returns a fencing token or ownership string if successful, or `null` if locked.
  Future<String?> acquire(String resource,
      {Duration ttl = const Duration(seconds: 10)});

  /// Releases the lock if [lockToken] matches current ownership.
  Future<bool> release(String resource, String lockToken);
}

/// Prevents cache stampedes (thundering herds) by coalescing concurrent
/// invocations for the same key into a single asynchronous operation.
class SingleFlightCoordinator {
  SingleFlightCoordinator({this.distributedLock});

  final DistributedLockProvider? distributedLock;
  final Map<String, Future<dynamic>> _inFlight = {};

  /// Executes [action] or joins an existing in-flight future for [key].
  Future<T> run<T>(String key, Future<T> Function() action) async {
    final existing = _inFlight[key];
    if (existing != null) {
      return (await existing) as T;
    }

    final completer = Completer<T>();
    _inFlight[key] = completer.future;

    try {
      final result = await _executeWithLock(key, action);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<T> _executeWithLock<T>(String key, Future<T> Function() action) async {
    if (distributedLock == null) {
      return await action();
    }

    String? token;
    final lockResource = 'lock:$key';
    for (var i = 0; i < 5; i++) {
      token = await distributedLock!.acquire(lockResource);
      if (token != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    try {
      return await action();
    } finally {
      if (token != null) {
        await distributedLock!.release(lockResource, token);
      }
    }
  }
}
