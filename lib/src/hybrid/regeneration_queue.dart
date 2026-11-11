import 'dart:convert';
import 'dart:io';

enum RegenerationJobStatus { queued, processing, completed, failed, cancelled }

/// Durable single-host regeneration job record.
class RegenerationJob {
  const RegenerationJob({
    required this.id,
    required this.siteId,
    required this.tenantId,
    required this.path,
    required this.routeId,
    required this.tags,
    required this.idempotencyKey,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.createdAt,
    required this.availableAt,
    this.sourceVersion,
    this.leaseUntil,
    this.leaseToken,
    this.errorCode,
  });

  final String id;
  final String siteId;
  final String tenantId;
  final String path;
  final String routeId;
  final List<String> tags;
  final String idempotencyKey;
  final String? sourceVersion;
  final RegenerationJobStatus status;
  final int attempts;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime availableAt;
  final DateTime? leaseUntil;

  /// Unique claim token. Required when completing or failing a leased job.
  final String? leaseToken;

  /// Sanitized identifier only; never store exception text or source data here.
  final String? errorCode;

  RegenerationJob copyWith({
    RegenerationJobStatus? status,
    int? attempts,
    DateTime? availableAt,
    DateTime? leaseUntil,
    String? leaseToken,
    String? errorCode,
    bool clearLease = false,
    bool clearError = false,
  }) =>
      RegenerationJob(
        id: id,
        siteId: siteId,
        tenantId: tenantId,
        path: path,
        routeId: routeId,
        tags: tags,
        idempotencyKey: idempotencyKey,
        sourceVersion: sourceVersion,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        maxAttempts: maxAttempts,
        createdAt: createdAt,
        availableAt: availableAt ?? this.availableAt,
        leaseUntil: clearLease ? null : leaseUntil ?? this.leaseUntil,
        leaseToken: clearLease ? null : leaseToken ?? this.leaseToken,
        errorCode: clearError ? null : errorCode ?? this.errorCode,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'siteId': siteId,
        'tenantId': tenantId,
        'path': path,
        'routeId': routeId,
        'tags': tags,
        'idempotencyKey': idempotencyKey,
        'sourceVersion': sourceVersion,
        'status': status.name,
        'attempts': attempts,
        'maxAttempts': maxAttempts,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'availableAt': availableAt.toUtc().toIso8601String(),
        'leaseUntil': leaseUntil?.toUtc().toIso8601String(),
        'leaseToken': leaseToken,
        'errorCode': errorCode,
      };

  factory RegenerationJob.fromJson(Map<String, Object?> json) =>
      RegenerationJob(
        id: json['id']! as String,
        siteId: json['siteId']! as String,
        tenantId: json['tenantId']! as String,
        path: json['path']! as String,
        routeId: json['routeId']! as String,
        tags: (json['tags']! as List).cast<String>(),
        idempotencyKey: json['idempotencyKey']! as String,
        sourceVersion: json['sourceVersion'] as String?,
        status: RegenerationJobStatus.values.byName(json['status']! as String),
        attempts: json['attempts']! as int,
        maxAttempts: json['maxAttempts']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String),
        availableAt: DateTime.parse(json['availableAt']! as String),
        leaseUntil: json['leaseUntil'] == null
            ? null
            : DateTime.parse(json['leaseUntil']! as String),
        leaseToken: json['leaseToken'] as String?,
        errorCode: json['errorCode'] as String?,
      );
}

/// Declares the operational capabilities of a regeneration queue implementation.
class QueueCapabilities {
  const QueueCapabilities({
    required this.isDistributed,
    required this.supportsFencing,
    required this.supportsBatchEnqueue,
    required this.supportsIdempotencyIndex,
    required this.supportsLeaseRenewal,
    required this.supportsScheduledRetries,
  });

  final bool isDistributed;
  final bool supportsFencing;
  final bool supportsBatchEnqueue;
  final bool supportsIdempotencyIndex;
  final bool supportsLeaseRenewal;
  final bool supportsScheduledRetries;

  Map<String, bool> toMap() => {
        'isDistributed': isDistributed,
        'supportsFencing': supportsFencing,
        'supportsBatchEnqueue': supportsBatchEnqueue,
        'supportsIdempotencyIndex': supportsIdempotencyIndex,
        'supportsLeaseRenewal': supportsLeaseRenewal,
        'supportsScheduledRetries': supportsScheduledRetries,
      };
}

/// One job request for batch enqueue operations.
class RegenerationJobRequest {
  const RegenerationJobRequest({
    required this.siteId,
    required this.tenantId,
    required this.path,
    required this.routeId,
    required this.tags,
    required this.idempotencyKey,
    this.sourceVersion,
    this.maxAttempts = 5,
  });

  final String siteId;
  final String tenantId;
  final String path;
  final String routeId;
  final List<String> tags;
  final String idempotencyKey;
  final String? sourceVersion;
  final int maxAttempts;
}

/// Point-in-time metrics for queue observability and capacity monitoring.
class QueueMetrics {
  const QueueMetrics({
    required this.totalJobs,
    required this.queuedJobs,
    required this.processingJobs,
    required this.completedJobs,
    required this.failedJobs,
    required this.cancelledJobs,
  });

  final int totalJobs;
  final int queuedJobs;
  final int processingJobs;
  final int completedJobs;
  final int failedJobs;
  final int cancelledJobs;

  Map<String, int> toMap() => {
        'totalJobs': totalJobs,
        'queuedJobs': queuedJobs,
        'processingJobs': processingJobs,
        'completedJobs': completedJobs,
        'failedJobs': failedJobs,
        'cancelledJobs': cancelledJobs,
      };
}

/// Abstract contract for durable and distributed job queues in MetaMantle.
abstract interface class RegenerationQueue {
  QueueCapabilities get capabilities;

  Future<RegenerationJob> enqueue({
    required String siteId,
    required String tenantId,
    required String path,
    required String routeId,
    required List<String> tags,
    required String idempotencyKey,
    String? sourceVersion,
    int maxAttempts = 5,
    DateTime? now,
  });

  Future<List<RegenerationJob>> enqueueAll(
    List<RegenerationJobRequest> requests, {
    DateTime? now,
  });

  Future<RegenerationJob?> claimNext({
    DateTime? now,
    Duration lease = const Duration(minutes: 2),
  });

  Future<RegenerationJob> complete(String id, {required String leaseToken});

  Future<RegenerationJob> fail(
    String id, {
    required String leaseToken,
    required String errorCode,
    DateTime? now,
  });

  Future<RegenerationJob> cancel(String id);

  Future<List<RegenerationJob>> list();

  Future<RegenerationJob?> getById(String id);

  Future<int> cleanupCompleted({Duration maxAge = const Duration(days: 7)});

  Future<QueueMetrics> metrics();
}

/// Persistent single-host filesystem queue with an O(1) persistent idempotency
/// index, indexed pending job resolution, batch scheduling, and exclusive lock fencing.
///
/// Multi-instance note: This queue uses operating-system file locks and is designed
/// for single-host deployments. Distributed multi-instance deployments require an
/// external database or Redis queue adapter with distributed locks.
class FileRegenerationQueue implements RegenerationQueue {
  FileRegenerationQueue(Directory directory, {this.maxProcessingJobs = 4})
      : directory = directory.absolute {
    if (maxProcessingJobs < 1 || maxProcessingJobs > 128) {
      throw ArgumentError('maxProcessingJobs must be between 1 and 128.');
    }
  }

  final Directory directory;
  final int maxProcessingJobs;

  @override
  QueueCapabilities get capabilities => const QueueCapabilities(
        isDistributed: false,
        supportsFencing: true,
        supportsBatchEnqueue: true,
        supportsIdempotencyIndex: true,
        supportsLeaseRenewal: true,
        supportsScheduledRetries: true,
      );

  Directory get _jobsDir =>
      Directory('${directory.path}${Platform.pathSeparator}jobs');
  Directory get _indexesDir =>
      Directory('${directory.path}${Platform.pathSeparator}indexes');
  File get _idempotencyFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}idempotency.json');
  File get _pendingFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}pending.json');
  File get _processingFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}processing.json');

  @override
  Future<RegenerationJob> enqueue({
    required String siteId,
    required String tenantId,
    required String path,
    required String routeId,
    required List<String> tags,
    required String idempotencyKey,
    String? sourceVersion,
    int maxAttempts = 5,
    DateTime? now,
  }) async =>
      _locked(() async {
        _validateId(siteId, 'siteId');
        _validateId(tenantId, 'tenantId');
        _validateId(routeId, 'routeId');
        _validateId(idempotencyKey, 'idempotencyKey');
        final normalized = _normalizeQueuePath(path);
        if (tags.any((tag) =>
            tag.trim().isEmpty || tag.length > 200 || tag.contains('\u0000'))) {
          throw const FormatException('Invalid job dependency tag.');
        }
        if (maxAttempts < 1 || maxAttempts > 20) {
          throw ArgumentError('maxAttempts must be between 1 and 20.');
        }

        final indexes = await _loadIndexes();
        final composite = '$siteId|$tenantId|$idempotencyKey';
        final existingId = indexes.idempotency[composite];
        if (existingId != null) {
          final existing = await _tryRead(existingId);
          if (existing != null &&
              existing.status != RegenerationJobStatus.cancelled) {
            return existing;
          }
        }

        final created = (now ?? DateTime.now()).toUtc();
        final id = '${created.microsecondsSinceEpoch}_${pid}_${_queueNonce()}';
        final job = RegenerationJob(
          id: id,
          siteId: siteId,
          tenantId: tenantId,
          path: normalized,
          routeId: routeId,
          tags: List.unmodifiable(tags.toSet().toList()..sort()),
          idempotencyKey: idempotencyKey,
          sourceVersion: sourceVersion,
          status: RegenerationJobStatus.queued,
          attempts: 0,
          maxAttempts: maxAttempts,
          createdAt: created,
          availableAt: created,
        );

        await _save(job);
        indexes.idempotency[composite] = id;
        indexes.pending.add(id);
        await _saveIndexes(indexes);
        return job;
      });

  @override
  Future<List<RegenerationJob>> enqueueAll(
    List<RegenerationJobRequest> requests, {
    DateTime? now,
  }) async =>
      _locked(() async {
        if (requests.isEmpty) return const [];
        final indexes = await _loadIndexes();
        final createdTime = (now ?? DateTime.now()).toUtc();
        final results = <RegenerationJob>[];
        final jobsToWrite = <RegenerationJob>[];

        for (final req in requests) {
          _validateId(req.siteId, 'siteId');
          _validateId(req.tenantId, 'tenantId');
          _validateId(req.routeId, 'routeId');
          _validateId(req.idempotencyKey, 'idempotencyKey');
          final normalized = _normalizeQueuePath(req.path);
          if (req.tags.any((tag) =>
              tag.trim().isEmpty ||
              tag.length > 200 ||
              tag.contains('\u0000'))) {
            throw const FormatException('Invalid job dependency tag.');
          }
          if (req.maxAttempts < 1 || req.maxAttempts > 20) {
            throw ArgumentError('maxAttempts must be between 1 and 20.');
          }

          final composite =
              '${req.siteId}|${req.tenantId}|${req.idempotencyKey}';
          final existingId = indexes.idempotency[composite];
          if (existingId != null) {
            final existing = await _tryRead(existingId);
            if (existing != null &&
                existing.status != RegenerationJobStatus.cancelled) {
              results.add(existing);
              continue;
            }
          }

          final id =
              '${createdTime.microsecondsSinceEpoch}_${pid}_${_queueNonce()}';
          final job = RegenerationJob(
            id: id,
            siteId: req.siteId,
            tenantId: req.tenantId,
            path: normalized,
            routeId: req.routeId,
            tags: List.unmodifiable(req.tags.toSet().toList()..sort()),
            idempotencyKey: req.idempotencyKey,
            sourceVersion: req.sourceVersion,
            status: RegenerationJobStatus.queued,
            attempts: 0,
            maxAttempts: req.maxAttempts,
            createdAt: createdTime,
            availableAt: createdTime,
          );

          jobsToWrite.add(job);
          indexes.idempotency[composite] = id;
          indexes.pending.add(id);
          results.add(job);
        }

        // Write new job files concurrently in bounded chunks
        for (var i = 0; i < jobsToWrite.length; i += 64) {
          final chunk = jobsToWrite.skip(i).take(64);
          await Future.wait(chunk.map(_save));
        }

        await _saveIndexes(indexes);
        return results;
      });

  @override
  Future<RegenerationJob?> claimNext({
    DateTime? now,
    Duration lease = const Duration(minutes: 2),
  }) async =>
      _locked(() async {
        if (lease <= Duration.zero) {
          throw ArgumentError('lease must be positive.');
        }
        final time = (now ?? DateTime.now()).toUtc();
        final indexes = await _loadIndexes();

        // 1. Recover expired leases from processing jobs
        final expiredJobIds = <String>[];
        for (final entry in indexes.processing.entries) {
          final leaseUntil = entry.value;
          if (!leaseUntil.isAfter(time)) {
            expiredJobIds.add(entry.key);
          }
        }

        for (final id in expiredJobIds) {
          indexes.processing.remove(id);
          final job = await _tryRead(id);
          if (job != null && job.status == RegenerationJobStatus.processing) {
            final recovered = job.attempts >= job.maxAttempts
                ? job.copyWith(
                    status: RegenerationJobStatus.failed,
                    clearLease: true,
                    errorCode: 'worker_lease_expired',
                  )
                : job.copyWith(
                    status: RegenerationJobStatus.queued,
                    availableAt: time,
                    clearLease: true,
                    errorCode: 'worker_lease_expired',
                  );
            await _save(recovered);
            if (recovered.status == RegenerationJobStatus.queued) {
              indexes.pending.add(id);
            }
          }
        }

        // 2. Enforce concurrency limits
        if (indexes.processing.length >= maxProcessingJobs) {
          await _saveIndexes(indexes);
          return null;
        }

        // 3. Track active processing paths for mutual exclusion
        final workingPaths = <String>{};
        for (final id in indexes.processing.keys) {
          final job = await _tryRead(id);
          if (job != null &&
              job.status == RegenerationJobStatus.processing &&
              job.leaseUntil != null &&
              job.leaseUntil!.isAfter(time)) {
            workingPaths.add('${job.siteId}|${job.tenantId}|${job.path}');
          }
        }

        // 4. Find the first eligible pending job
        String? claimedId;
        RegenerationJob? readyJob;

        for (final id in indexes.pending) {
          final job = await _tryRead(id);
          if (job == null || job.status != RegenerationJobStatus.queued) {
            continue;
          }
          if (!job.availableAt.isAfter(time) &&
              !workingPaths
                  .contains('${job.siteId}|${job.tenantId}|${job.path}')) {
            claimedId = id;
            readyJob = job;
            break;
          }
        }

        if (claimedId == null || readyJob == null) {
          await _saveIndexes(indexes);
          return null;
        }

        final leaseUntil = time.add(lease);
        final token = _queueNonce();
        final claimedJob = readyJob.copyWith(
          status: RegenerationJobStatus.processing,
          attempts: readyJob.attempts + 1,
          leaseUntil: leaseUntil,
          leaseToken: token,
          clearLease: false,
        );

        await _save(claimedJob);
        indexes.pending.remove(claimedId);
        indexes.processing[claimedId] = leaseUntil;
        await _saveIndexes(indexes);
        return claimedJob;
      });

  @override
  Future<RegenerationJob> complete(String id, {required String leaseToken}) =>
      _locked(() async {
        final job = await _read(id);
        if (job.status != RegenerationJobStatus.processing) {
          throw StateError('Only processing jobs can complete.');
        }
        _checkLeaseToken(job, leaseToken);
        final completed = job.copyWith(
          status: RegenerationJobStatus.completed,
          clearLease: true,
          clearError: true,
        );
        await _save(completed);

        final indexes = await _loadIndexes();
        indexes.processing.remove(id);
        indexes.pending.remove(id);
        await _saveIndexes(indexes);
        return completed;
      });

  @override
  Future<RegenerationJob> fail(
    String id, {
    required String leaseToken,
    required String errorCode,
    DateTime? now,
  }) =>
      _locked(() async {
        final job = await _read(id);
        if (job.status != RegenerationJobStatus.processing) {
          throw StateError('Only processing jobs can fail.');
        }
        _checkLeaseToken(job, leaseToken);
        if (!RegExp(r'^[a-z0-9_]{1,48}$').hasMatch(errorCode)) {
          throw ArgumentError('errorCode must be a safe identifier.');
        }
        final time = (now ?? DateTime.now()).toUtc();
        final exhausted = job.attempts >= job.maxAttempts;
        final exponent = job.attempts.clamp(0, 10).toInt();
        final delay = Duration(seconds: 1 << exponent);

        final updated = job.copyWith(
          status: exhausted
              ? RegenerationJobStatus.failed
              : RegenerationJobStatus.queued,
          availableAt: time.add(delay),
          clearLease: true,
          errorCode: errorCode,
        );
        await _save(updated);

        final indexes = await _loadIndexes();
        indexes.processing.remove(id);
        if (!exhausted) {
          indexes.pending.add(id);
        } else {
          indexes.pending.remove(id);
        }
        await _saveIndexes(indexes);
        return updated;
      });

  @override
  Future<RegenerationJob> cancel(String id) => _locked(() async {
        final job = await _read(id);
        if (job.status != RegenerationJobStatus.queued) {
          throw StateError('Only queued jobs can be cancelled.');
        }
        final cancelled = job.copyWith(status: RegenerationJobStatus.cancelled);
        await _save(cancelled);

        final indexes = await _loadIndexes();
        indexes.pending.remove(id);
        await _saveIndexes(indexes);
        return cancelled;
      });

  @override
  Future<List<RegenerationJob>> list() => _locked(_allJobs);

  @override
  Future<RegenerationJob?> getById(String id) async => _tryRead(id);

  @override
  Future<int> cleanupCompleted({
    Duration maxAge = const Duration(days: 7),
  }) async =>
      _locked(() async {
        final now = DateTime.now().toUtc();
        final all = await _allJobs();
        final indexes = await _loadIndexes();
        var deletedCount = 0;

        for (final job in all) {
          if (job.status == RegenerationJobStatus.completed ||
              job.status == RegenerationJobStatus.cancelled) {
            if (now.difference(job.createdAt) > maxAge) {
              final file = _jobFile(job.id);
              if (await file.exists()) await file.delete();
              indexes.idempotency.remove(
                  '${job.siteId}|${job.tenantId}|${job.idempotencyKey}');
              indexes.pending.remove(job.id);
              indexes.processing.remove(job.id);
              deletedCount++;
            }
          }
        }

        if (deletedCount > 0) {
          await _saveIndexes(indexes);
        }
        return deletedCount;
      });

  @override
  Future<QueueMetrics> metrics() => _locked(() async {
        final all = await _allJobs();
        var queued = 0;
        var processing = 0;
        var completed = 0;
        var failed = 0;
        var cancelled = 0;

        for (final job in all) {
          switch (job.status) {
            case RegenerationJobStatus.queued:
              queued++;
            case RegenerationJobStatus.processing:
              processing++;
            case RegenerationJobStatus.completed:
              completed++;
            case RegenerationJobStatus.failed:
              failed++;
            case RegenerationJobStatus.cancelled:
              cancelled++;
          }
        }

        return QueueMetrics(
          totalJobs: all.length,
          queuedJobs: queued,
          processingJobs: processing,
          completedJobs: completed,
          failedJobs: failed,
          cancelledJobs: cancelled,
        );
      });

  /// Reconstructs corrupted or missing queue indexes from stored job records.
  Future<void> rebuildIndexes() => _locked(_rebuildIndexesInternal);

  Future<void> _rebuildIndexesInternal() async {
    final all = await _allJobs();
    final newIdempotency = <String, String>{};
    final newPending = <String>[];
    final newProcessing = <String, DateTime>{};

    for (final job in all) {
      if (job.status != RegenerationJobStatus.cancelled) {
        newIdempotency['${job.siteId}|${job.tenantId}|${job.idempotencyKey}'] =
            job.id;
      }
      if (job.status == RegenerationJobStatus.queued) {
        newPending.add(job.id);
      } else if (job.status == RegenerationJobStatus.processing &&
          job.leaseUntil != null) {
        newProcessing[job.id] = job.leaseUntil!;
      }
    }

    await _saveIndexes(_QueueIndexData(
      idempotency: newIdempotency,
      pending: newPending,
      processing: newProcessing,
    ));
  }

  Future<_QueueIndexData> _loadIndexes() async {
    await _indexesDir.create(recursive: true);
    if (!await _idempotencyFile.exists()) {
      await _rebuildIndexesInternal();
    }
    try {
      final idempotencyMap = <String, String>{};
      if (await _idempotencyFile.exists()) {
        final decoded =
            jsonDecode(await _idempotencyFile.readAsString()) as Map;
        for (final entry in decoded.entries) {
          idempotencyMap[entry.key as String] = entry.value as String;
        }
      }

      final pendingList = <String>[];
      if (await _pendingFile.exists()) {
        final decoded = jsonDecode(await _pendingFile.readAsString()) as List;
        for (final item in decoded) {
          pendingList.add(item as String);
        }
      }

      final processingMap = <String, DateTime>{};
      if (await _processingFile.exists()) {
        final decoded = jsonDecode(await _processingFile.readAsString()) as Map;
        for (final entry in decoded.entries) {
          processingMap[entry.key as String] =
              DateTime.parse(entry.value as String);
        }
      }

      return _QueueIndexData(
        idempotency: idempotencyMap,
        pending: pendingList,
        processing: processingMap,
      );
    } catch (_) {
      await _rebuildIndexesInternal();
      return _loadIndexes();
    }
  }

  Future<void> _saveIndexes(_QueueIndexData indexes) async {
    await _indexesDir.create(recursive: true);
    await _writeAtomicJson(_idempotencyFile, indexes.idempotency);
    await _writeAtomicJson(_pendingFile, indexes.pending);
    await _writeAtomicJson(
        _processingFile,
        indexes.processing
            .map((k, v) => MapEntry(k, v.toUtc().toIso8601String())));
  }

  Future<void> _writeAtomicJson(File file, Object value) async {
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  void _checkLeaseToken(RegenerationJob job, String token) {
    if (job.leaseToken == null || job.leaseToken != token) {
      throw StateError('Regeneration job lease is no longer owned.');
    }
  }

  Future<T> _locked<T>(Future<T> Function() action) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}.queue.lock');
    final handle = await file.open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    try {
      return await action();
    } finally {
      await handle.unlock();
      await handle.close();
    }
  }

  File _jobFile(String id) {
    return File('${_jobsDir.path}${Platform.pathSeparator}$id.job.json');
  }

  File _legacyJobFile(String id) {
    return File('${directory.path}${Platform.pathSeparator}$id.job.json');
  }

  Future<List<RegenerationJob>> _allJobs() async {
    final result = <RegenerationJob>[];
    final seen = <String>{};

    if (await _jobsDir.exists()) {
      await for (final entity in _jobsDir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.job.json')) continue;
        final decoded = jsonDecode(await entity.readAsString()) as Map;
        final job =
            RegenerationJob.fromJson(Map<String, Object?>.from(decoded));
        seen.add(job.id);
        result.add(job);
      }
    }

    // Include any legacy jobs in the root directory
    if (await directory.exists()) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.job.json')) continue;
        final decoded = jsonDecode(await entity.readAsString()) as Map;
        final job =
            RegenerationJob.fromJson(Map<String, Object?>.from(decoded));
        if (!seen.contains(job.id)) {
          result.add(job);
        }
      }
    }
    return result;
  }

  Future<RegenerationJob?> _tryRead(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(id)) return null;
    final file = _jobFile(id);
    if (await file.exists()) {
      return RegenerationJob.fromJson(Map<String, Object?>.from(
          jsonDecode(await file.readAsString()) as Map));
    }
    final legacy = _legacyJobFile(id);
    if (await legacy.exists()) {
      return RegenerationJob.fromJson(Map<String, Object?>.from(
          jsonDecode(await legacy.readAsString()) as Map));
    }
    return null;
  }

  Future<RegenerationJob> _read(String id) async {
    final job = await _tryRead(id);
    if (job == null) throw StateError('Regeneration job not found.');
    return job;
  }

  Future<void> _save(RegenerationJob job) async {
    await _jobsDir.create(recursive: true);
    final path = '${_jobsDir.path}${Platform.pathSeparator}${job.id}.job.json';
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(job.toJson()),
      flush: true,
    );
  }

  void _validateId(String value, String name) {
    if (value.trim().isEmpty ||
        value.length > 120 ||
        value.contains('\u0000')) {
      throw ArgumentError('$name is invalid.');
    }
  }
}

class _QueueIndexData {
  _QueueIndexData({
    required this.idempotency,
    required this.pending,
    required this.processing,
  });

  final Map<String, String> idempotency;
  final List<String> pending;
  final Map<String, DateTime> processing;
}

String _normalizeQueuePath(String path) {
  if (!path.startsWith('/') ||
      path.contains('\\') ||
      path.contains('?') ||
      path.contains('#') ||
      path.contains('\u0000') ||
      path.split('/').any((segment) => segment == '.' || segment == '..')) {
    throw const FormatException('Invalid regeneration path.');
  }
  final compact = path.replaceAll(RegExp(r'/+'), '/');
  return compact == '/' ? '/' : compact.replaceFirst(RegExp(r'/$'), '');
}

var _nonceSeq = 0;
String _queueNonce() =>
    '${DateTime.now().microsecondsSinceEpoch}_${pid}_${++_nonceSeq}';

enum RegenerationWorkerResult {
  idle,
  completed,
  retryScheduled,
  failed,
  leaseLost
}

/// Executes one durable job. The handler must load authoritative current data;
/// exceptions are recorded only as a safe, caller-selected error code.
class RegenerationWorker {
  const RegenerationWorker({
    required this.queue,
    required this.handle,
    this.errorCode = 'regeneration_failed',
  });

  final RegenerationQueue queue;
  final Future<void> Function(RegenerationJob job) handle;
  final String errorCode;

  Future<RegenerationWorkerResult> processNext({DateTime? now}) async {
    final job = await queue.claimNext(now: now);
    if (job == null) return RegenerationWorkerResult.idle;
    final token = job.leaseToken;
    if (token == null) return RegenerationWorkerResult.leaseLost;
    try {
      await handle(job);
      await queue.complete(job.id, leaseToken: token);
      return RegenerationWorkerResult.completed;
    } on Object {
      try {
        final failed = await queue.fail(job.id,
            leaseToken: token, errorCode: errorCode, now: now);
        return failed.status == RegenerationJobStatus.failed
            ? RegenerationWorkerResult.failed
            : RegenerationWorkerResult.retryScheduled;
      } on StateError {
        // A later claim replaced this worker's token; it cannot publish status.
        return RegenerationWorkerResult.leaseLost;
      }
    }
  }
}
