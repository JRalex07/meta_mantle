import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'hybrid_generation.dart';
import 'regeneration_queue.dart';

/// Result of scheduling one explicit revalidation event.
class HybridEnqueueReport {
  const HybridEnqueueReport(this.jobs);

  final List<RegenerationJob> jobs;
  List<String> get jobIds => List.unmodifiable(jobs.map((job) => job.id));
}

/// Maps path, tag, and route events to durable jobs for one site/tenant store.
/// Use separate stores and queue directories for tenants; dependency indexes
/// themselves are intentionally not tenant-aware.
class HybridRevalidationScheduler {
  const HybridRevalidationScheduler({
    required this.store,
    required this.queue,
    required this.siteId,
    required this.tenantId,
  });

  final FileHtmlArtifactStore store;
  final FileRegenerationQueue queue;
  final String siteId;
  final String tenantId;

  Future<HybridEnqueueReport> revalidatePath(
    String path, {
    required String eventId,
  }) async {
    final normalized = _normalizePath(path);
    final dependencies = await store.loadDependencies();
    final dependency = dependencies[normalized];
    if (dependency == null) return const HybridEnqueueReport([]);
    return _enqueue([dependency], eventId);
  }

  Future<HybridEnqueueReport> revalidateTag(
    String tag, {
    required String eventId,
  }) async {
    _validateTag(tag);
    final version = await store.activeVersion;
    final dependencies = version == null
        ? await store.loadDependencies()
        : await store.loadVersionDependencies(version);
    final paths = version == null
        ? dependencies.values
            .where((dependency) => dependency.tags.contains(tag))
            .map((dependency) => dependency.path)
            .toList()
        : await store.loadVersionTagPaths(version, tag);
    return _enqueue(
      paths
          .map((path) => dependencies[path])
          .whereType<RouteDependency>()
          .toList(),
      eventId,
    );
  }

  Future<HybridEnqueueReport> revalidateRoute(
    String routeId, {
    required String eventId,
  }) async {
    if (routeId.trim().isEmpty || routeId.length > 200) {
      throw const FormatException('Invalid route ID.');
    }
    final version = await store.activeVersion;
    final dependencies = version == null
        ? await store.loadDependencies()
        : await store.loadVersionDependencies(version);
    final paths = version == null
        ? dependencies.values
            .where((dependency) => dependency.routeId == routeId)
            .map((dependency) => dependency.path)
            .toList()
        : await store.loadVersionRoutePaths(version, routeId);
    return _enqueue(
      paths
          .map((path) => dependencies[path])
          .whereType<RouteDependency>()
          .toList(),
      eventId,
    );
  }

  Future<HybridEnqueueReport> revalidateAll({required String eventId}) async {
    final dependencies = await store.loadDependencies();
    return _enqueue(dependencies.values.toList(), eventId);
  }

  /// Enqueues pages whose last successful generation is at least [maxAge] old.
  /// Call this from an application-owned cron or scheduler; this package does
  /// not start a background timer or keep a process alive.
  Future<HybridEnqueueReport> revalidateExpired({
    required Duration maxAge,
    required String eventId,
    DateTime? now,
    int maxJobs = 10000,
  }) async {
    if (maxAge <= Duration.zero) {
      throw ArgumentError.value(maxAge, 'maxAge', 'Must be positive.');
    }
    if (maxJobs < 1 || maxJobs > 100000) {
      throw ArgumentError.value(
          maxJobs, 'maxJobs', 'Must be between 1 and 100000.');
    }
    final dependencies = await store.loadDependencies();
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(maxAge);
    final expired = dependencies.values
        .where((dependency) => !dependency.generatedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (expired.length > maxJobs) {
      throw StateError(
        'Expired route count exceeds maxJobs; increase maxJobs or schedule smaller route groups.',
      );
    }
    return _enqueue(expired, eventId);
  }

  Future<HybridEnqueueReport> _enqueue(
      List<RouteDependency> dependencies, String eventId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(eventId)) {
      throw const FormatException('Invalid revalidation event ID.');
    }
    final ordered = dependencies.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final jobs = <RegenerationJob>[];
    for (final dependency in ordered) {
      final pathDigest = sha256.convert(utf8.encode(dependency.path));
      jobs.add(await queue.enqueue(
        siteId: siteId,
        tenantId: tenantId,
        path: dependency.path,
        routeId: dependency.routeId,
        tags: dependency.tags,
        sourceVersion: dependency.sourceVersion,
        idempotencyKey: '$eventId:$pathDigest',
      ));
    }
    return HybridEnqueueReport(List.unmodifiable(jobs));
  }
}

void _validateTag(String tag) {
  if (tag.trim().isEmpty || tag.length > 200 || tag.contains('\u0000')) {
    throw const FormatException('Invalid dependency tag.');
  }
}

String _normalizePath(String path) {
  if (!path.startsWith('/') ||
      path.contains('\\') ||
      path.contains('?') ||
      path.contains('#') ||
      path.contains('\u0000') ||
      path.split('/').any((segment) => segment == '.' || segment == '..')) {
    throw const FormatException('Invalid revalidation path.');
  }
  final compact = path.replaceAll(RegExp(r'/+'), '/');
  return compact == '/' ? '/' : compact.replaceFirst(RegExp(r'/$'), '');
}
