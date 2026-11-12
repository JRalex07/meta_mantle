import 'dart:async';
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
    this.fencingEpoch,
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

  /// Monotonic fence epoch indicating the ownership revision of this leased job.
  final int? fencingEpoch;

  RegenerationJob copyWith({
    RegenerationJobStatus? status,
    int? attempts,
    DateTime? availableAt,
    DateTime? leaseUntil,
    String? leaseToken,
    String? errorCode,
    int? fencingEpoch,
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
        fencingEpoch: clearLease ? null : fencingEpoch ?? this.fencingEpoch,
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
        'fencingEpoch': fencingEpoch,
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
        fencingEpoch: json['fencingEpoch'] as int?,
      );
}

/// Diagnostic report emitted when recovering persistent queue state after restart or crash.
class QueueRecoveryReport {
  const QueueRecoveryReport({
    required this.journalEntriesReplayed,
    required this.recoveredJobs,
    required this.corruptedEntriesDiscarded,
    required this.rebuiltFromDisk,
    required this.activePendingCount,
    required this.activeProcessingCount,
    required this.idempotencyCount,
  });

  final int journalEntriesReplayed;
  final int recoveredJobs;
  final int corruptedEntriesDiscarded;
  final bool rebuiltFromDisk;
  final int activePendingCount;
  final int activeProcessingCount;
  final int idempotencyCount;

  Map<String, Object?> toJson() => {
        'journalEntriesReplayed': journalEntriesReplayed,
        'recoveredJobs': recoveredJobs,
        'corruptedEntriesDiscarded': corruptedEntriesDiscarded,
        'rebuiltFromDisk': rebuiltFromDisk,
        'activePendingCount': activePendingCount,
        'activeProcessingCount': activeProcessingCount,
        'idempotencyCount': idempotencyCount,
      };
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
    this.supportsCrashRecovery = true,
    this.supportsPersistentJournal = true,
  });

  final bool isDistributed;
  final bool supportsFencing;
  final bool supportsBatchEnqueue;
  final bool supportsIdempotencyIndex;
  final bool supportsLeaseRenewal;
  final bool supportsScheduledRetries;
  final bool supportsCrashRecovery;
  final bool supportsPersistentJournal;

  Map<String, bool> toMap() => {
        'isDistributed': isDistributed,
        'supportsFencing': supportsFencing,
        'supportsBatchEnqueue': supportsBatchEnqueue,
        'supportsIdempotencyIndex': supportsIdempotencyIndex,
        'supportsLeaseRenewal': supportsLeaseRenewal,
        'supportsScheduledRetries': supportsScheduledRetries,
        'supportsCrashRecovery': supportsCrashRecovery,
        'supportsPersistentJournal': supportsPersistentJournal,
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

  /// Extends the lease duration of an actively processing job owned by [leaseToken].
  Future<RegenerationJob> renewLease(
    String id, {
    required String leaseToken,
    Duration extension = const Duration(minutes: 2),
    DateTime? now,
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

  /// Validates journal and index consistency, repairing any crash-interrupted writes.
  Future<QueueRecoveryReport> recover();

  /// Forces an atomic compaction checkpoint of the write-ahead journal to a snapshot.
  Future<void> checkpoint();
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
        supportsCrashRecovery: true,
        supportsPersistentJournal: true,
      );

  Directory get _jobsDir =>
      Directory('${directory.path}${Platform.pathSeparator}jobs');
  Directory get _indexesDir =>
      Directory('${directory.path}${Platform.pathSeparator}indexes');
  File get _journalFile =>
      File('${directory.path}${Platform.pathSeparator}.queue.journal');
  File get _snapshotFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}snapshot.json');
  File get _idempotencyFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}idempotency.json');
  File get _pendingFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}pending.json');
  File get _processingFile =>
      File('${_indexesDir.path}${Platform.pathSeparator}processing.json');

  _QueueState? _state;
  int _journalOffset = 0;

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

        final state = await _syncState();
        final composite = '$siteId|$tenantId|$idempotencyKey';
        final existingId = state.idempotency[composite];
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
        state.idempotency[composite] = id;
        state.pending.add(id);

        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'enqueue',
          'id': id,
          'composite': composite,
          'time': created.toIso8601String(),
        });

        if (state.lastSeq % 1000 == 0) {
          await _checkpointInternal();
        }

        return job;
      });

  @override
  Future<List<RegenerationJob>> enqueueAll(
    List<RegenerationJobRequest> requests, {
    DateTime? now,
  }) async =>
      _locked(() async {
        if (requests.isEmpty) return const [];
        final state = await _syncState();
        final createdTime = (now ?? DateTime.now()).toUtc();
        final results = <RegenerationJob>[];
        final jobsToWrite = <RegenerationJob>[];
        final journalBatchEntries = <Map<String, Object?>>[];

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
          final existingId = state.idempotency[composite];
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
          state.idempotency[composite] = id;
          state.pending.add(id);
          results.add(job);
          journalBatchEntries.add({
            'id': id,
            'composite': composite,
          });
        }

        // Write new job files concurrently in bounded chunks
        for (var i = 0; i < jobsToWrite.length; i += 64) {
          final chunk = jobsToWrite.skip(i).take(64);
          await Future.wait(chunk.map(_save));
        }

        if (journalBatchEntries.isNotEmpty) {
          await _appendJournal({
            'seq': ++state.lastSeq,
            'op': 'enqueue_batch',
            'jobs': journalBatchEntries,
          });
        }

        if (state.lastSeq % 1000 == 0) {
          await _checkpointInternal();
        }

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
        final state = await _syncState();

        // 1. Recover expired leases from processing jobs
        final expiredJobIds = <String>[];
        for (final entry in state.processing.entries) {
          final leaseUntil = entry.value;
          if (!leaseUntil.isAfter(time)) {
            expiredJobIds.add(entry.key);
          }
        }

        for (final id in expiredJobIds) {
          state.processing.remove(id);
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
              state.pending.add(id);
            }
            await _appendJournal({
              'seq': ++state.lastSeq,
              'op': 'fail',
              'id': id,
              'status': recovered.status.name,
              'token': job.leaseToken,
            });
          }
        }

        // 2. Enforce concurrency limits
        if (state.processing.length >= maxProcessingJobs) {
          return null;
        }

        // 3. Track active processing paths for mutual exclusion
        final workingPaths = <String>{};
        for (final id in state.processing.keys) {
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

        for (final id in state.pending) {
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
          return null;
        }

        state.currentEpoch++;
        final leaseUntil = time.add(lease);
        final token =
            'epoch_${state.currentEpoch}_${readyJob.id}_${_queueNonce()}';
        final claimedJob = readyJob.copyWith(
          status: RegenerationJobStatus.processing,
          attempts: readyJob.attempts + 1,
          leaseUntil: leaseUntil,
          leaseToken: token,
          fencingEpoch: state.currentEpoch,
          clearLease: false,
        );

        await _save(claimedJob);
        state.pending.remove(claimedId);
        state.processing[claimedId] = leaseUntil;

        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'claim',
          'id': claimedId,
          'leaseUntil': leaseUntil.toIso8601String(),
          'token': token,
          'epoch': state.currentEpoch,
        });

        if (state.lastSeq % 1000 == 0) {
          await _checkpointInternal();
        }

        return claimedJob;
      });

  @override
  Future<RegenerationJob> renewLease(
    String id, {
    required String leaseToken,
    Duration extension = const Duration(minutes: 2),
    DateTime? now,
  }) =>
      _locked(() async {
        final job = await _read(id);
        if (job.status != RegenerationJobStatus.processing) {
          throw StateError('Only processing jobs can renew their lease.');
        }
        _checkLeaseToken(job, leaseToken);
        final time = (now ?? DateTime.now()).toUtc();
        final newLeaseUntil = time.add(extension);
        final renewed = job.copyWith(
          leaseUntil: newLeaseUntil,
        );
        await _save(renewed);

        final state = await _syncState();
        state.processing[id] = newLeaseUntil;
        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'renew',
          'id': id,
          'leaseUntil': newLeaseUntil.toIso8601String(),
          'token': leaseToken,
        });

        return renewed;
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

        final state = await _syncState();
        state.processing.remove(id);
        state.pending.remove(id);

        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'complete',
          'id': id,
          'token': leaseToken,
        });

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

        final state = await _syncState();
        state.processing.remove(id);
        if (!exhausted) {
          state.pending.add(id);
        } else {
          state.pending.remove(id);
        }

        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'fail',
          'id': id,
          'token': leaseToken,
          'status': updated.status.name,
          'availableAt': updated.availableAt.toIso8601String(),
          'errorCode': errorCode,
        });

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

        final state = await _syncState();
        state.pending.remove(id);
        final composite = '${job.siteId}|${job.tenantId}|${job.idempotencyKey}';
        state.idempotency.remove(composite);

        await _appendJournal({
          'seq': ++state.lastSeq,
          'op': 'cancel',
          'id': id,
          'composite': composite,
        });

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
        final state = await _syncState();
        var deletedCount = 0;
        final deletedIds = <String>[];

        for (final job in all) {
          if (job.status == RegenerationJobStatus.completed ||
              job.status == RegenerationJobStatus.cancelled) {
            if (now.difference(job.createdAt) > maxAge) {
              final file = _jobFile(job.id);
              if (await file.exists()) await file.delete();
              state.idempotency.remove(
                  '${job.siteId}|${job.tenantId}|${job.idempotencyKey}');
              state.pending.remove(job.id);
              state.processing.remove(job.id);
              deletedIds.add(job.id);
              deletedCount++;
            }
          }
        }

        if (deletedCount > 0) {
          await _appendJournal({
            'seq': ++state.lastSeq,
            'op': 'cleanup',
            'deletedIds': deletedIds,
          });
          await _checkpointInternal();
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

  /// Forces an atomic compaction checkpoint of the write-ahead journal to a snapshot.
  @override
  Future<void> checkpoint() => _locked(_checkpointInternal);

  Future<void> _checkpointInternal() async {
    final state = await _syncState();
    await _saveSnapshot(state);
    if (await _journalFile.exists()) {
      await _journalFile.writeAsString('', flush: true);
    }
    _journalOffset = 0;
  }

  /// Recovers persistent queue state by validating journal entries and reconciling stored jobs.
  @override
  Future<QueueRecoveryReport> recover() => _locked(() async {
        var corruptedEntriesDiscarded = 0;
        var recoveredJobs = 0;

        // 1. Truncate incomplete journal line if present
        if (await _journalFile.exists()) {
          final bytes = await _journalFile.readAsBytes();
          if (bytes.isNotEmpty && bytes.last != 10) {
            final lastNewline = bytes.lastIndexOf(10);
            if (lastNewline >= 0) {
              await _journalFile.writeAsBytes(bytes.sublist(0, lastNewline + 1),
                  flush: true);
              corruptedEntriesDiscarded++;
            } else {
              await _journalFile.delete();
              corruptedEntriesDiscarded++;
            }
          }
        }

        // 2. Reload state
        _state = null;
        final state = await _syncState();

        // 3. Scan jobs directory for unindexed or uncommitted jobs
        final diskJobs = await _allJobs();
        for (final job in diskJobs) {
          if (job.status == RegenerationJobStatus.queued) {
            final composite =
                '${job.siteId}|${job.tenantId}|${job.idempotencyKey}';
            if (!state.idempotency.containsKey(composite) ||
                !state.pending.contains(job.id)) {
              state.idempotency[composite] = job.id;
              state.pending.add(job.id);
              recoveredJobs++;
            }
          } else if (job.status == RegenerationJobStatus.processing &&
              job.leaseUntil != null) {
            if (!state.processing.containsKey(job.id)) {
              state.processing[job.id] = job.leaseUntil!;
              recoveredJobs++;
            }
          }
        }

        await _checkpointInternal();

        return QueueRecoveryReport(
          journalEntriesReplayed: state.lastSeq,
          recoveredJobs: recoveredJobs,
          corruptedEntriesDiscarded: corruptedEntriesDiscarded,
          rebuiltFromDisk: true,
          activePendingCount: state.pending.length,
          activeProcessingCount: state.processing.length,
          idempotencyCount: state.idempotency.length,
        );
      });

  /// Reconstructs corrupted or missing queue indexes from stored job records.
  Future<void> rebuildIndexes() => _locked(() async {
        final state = await _rebuildStateFromDisk();
        _state = state;
        await _checkpointInternal();
      });

  Future<_QueueState> _syncState() async {
    await _indexesDir.create(recursive: true);
    await _jobsDir.create(recursive: true);

    if (_state == null) {
      _QueueState state;
      if (await _snapshotFile.exists()) {
        try {
          final decoded = jsonDecode(await _snapshotFile.readAsString()) as Map;
          final idempotencyMap = (decoded['idempotency'] as Map? ?? {})
              .map((k, v) => MapEntry(k as String, v as String));
          final pendingSet =
              Set<String>.from(decoded['pending'] as List? ?? []);
          final processingMap = (decoded['processing'] as Map? ?? {}).map(
              (k, v) => MapEntry(k as String, DateTime.parse(v as String)));
          final epoch = (decoded['epoch'] as int?) ?? 0;
          final lastSeq = (decoded['lastSeq'] as int?) ?? 0;
          state = _QueueState(
            idempotency: idempotencyMap,
            pending: pendingSet,
            processing: processingMap,
            currentEpoch: epoch,
            lastSeq: lastSeq,
          );
        } catch (_) {
          state = await _rebuildStateFromDisk();
        }
      } else if (await _idempotencyFile.exists()) {
        final legacyIndexes = await _loadLegacyIndexes();
        state = _QueueState(
          idempotency: legacyIndexes.idempotency,
          pending: legacyIndexes.pending.toSet(),
          processing: legacyIndexes.processing,
        );
        await _saveSnapshot(state);
      } else {
        state = await _rebuildStateFromDisk();
      }

      if (await _journalFile.exists()) {
        await _replayJournal(state, seekOffset: 0);
      }
      _state = state;
      _journalOffset =
          await _journalFile.exists() ? await _journalFile.length() : 0;
      return _state!;
    }

    if (await _journalFile.exists()) {
      final currentLen = await _journalFile.length();
      if (currentLen > _journalOffset) {
        await _replayJournal(_state!, seekOffset: _journalOffset);
        _journalOffset = currentLen;
      } else if (currentLen < _journalOffset) {
        _state = null;
        return _syncState();
      }
    }
    return _state!;
  }

  Future<int> _replayJournal(_QueueState state, {int seekOffset = 0}) async {
    if (!await _journalFile.exists()) return 0;
    final handle = await _journalFile.open(mode: FileMode.read);
    var replayedCount = 0;
    try {
      if (seekOffset > 0) {
        await handle.setPosition(seekOffset);
      }
      final fileLength = await handle.length();
      final remainingBytes = fileLength - seekOffset;
      if (remainingBytes <= 0) return 0;
      final bytes = await handle.read(remainingBytes);
      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final entry = jsonDecode(trimmed) as Map;
          final seq = entry['seq'] as int? ?? 0;
          if (seq <= state.lastSeq && seekOffset == 0 && state.lastSeq > 0) {
            continue;
          }
          final op = entry['op'] as String?;
          switch (op) {
            case 'enqueue':
              final id = entry['id'] as String;
              final composite = entry['composite'] as String;
              state.idempotency[composite] = id;
              state.pending.add(id);
              state.lastSeq = seq;
              replayedCount++;
            case 'enqueue_batch':
              final list = entry['jobs'] as List? ?? [];
              for (final item in list) {
                final map = item as Map;
                state.idempotency[map['composite'] as String] =
                    map['id'] as String;
                state.pending.add(map['id'] as String);
              }
              state.lastSeq = seq;
              replayedCount++;
            case 'claim':
              final id = entry['id'] as String;
              final leaseUntil = DateTime.parse(entry['leaseUntil'] as String);
              final epoch = entry['epoch'] as int? ?? 0;
              state.pending.remove(id);
              state.processing[id] = leaseUntil;
              if (epoch > state.currentEpoch) {
                state.currentEpoch = epoch;
              }
              state.lastSeq = seq;
              replayedCount++;
            case 'renew':
              final id = entry['id'] as String;
              final leaseUntil = DateTime.parse(entry['leaseUntil'] as String);
              state.processing[id] = leaseUntil;
              state.lastSeq = seq;
              replayedCount++;
            case 'complete':
              final id = entry['id'] as String;
              state.processing.remove(id);
              state.pending.remove(id);
              state.lastSeq = seq;
              replayedCount++;
            case 'fail':
              final id = entry['id'] as String;
              final status = entry['status'] as String?;
              state.processing.remove(id);
              if (status == 'queued') {
                state.pending.add(id);
              } else {
                state.pending.remove(id);
              }
              state.lastSeq = seq;
              replayedCount++;
            case 'cancel':
              final id = entry['id'] as String;
              final composite = entry['composite'] as String?;
              state.processing.remove(id);
              state.pending.remove(id);
              if (composite != null) state.idempotency.remove(composite);
              state.lastSeq = seq;
              replayedCount++;
            case 'cleanup':
              final ids =
                  (entry['deletedIds'] as List? ?? []).cast<String>().toSet();
              state.pending.removeAll(ids);
              state.processing.removeWhere((k, _) => ids.contains(k));
              state.idempotency.removeWhere((_, v) => ids.contains(v));
              state.lastSeq = seq;
              replayedCount++;
          }
        } catch (_) {
          break;
        }
      }
    } finally {
      await handle.close();
    }
    return replayedCount;
  }

  Future<void> _appendJournal(Map<String, Object?> entry) async {
    await directory.create(recursive: true);
    final line = '${jsonEncode(entry)}\n';
    final handle = await _journalFile.open(mode: FileMode.append);
    try {
      await handle.writeString(line);
      await handle.flush();
    } finally {
      await handle.close();
    }
    _journalOffset = await _journalFile.length();
  }

  Future<void> _saveSnapshot(_QueueState state) async {
    await _indexesDir.create(recursive: true);
    final data = {
      'seq': state.lastSeq,
      'epoch': state.currentEpoch,
      'idempotency': state.idempotency,
      'pending': state.pending.toList(),
      'processing': state.processing
          .map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    };
    final jsonStr = jsonEncode(data);
    final temp = File('${_snapshotFile.path}.${_queueNonce()}.tmp');
    try {
      await temp.writeAsString(jsonStr, flush: true);
      if (await _snapshotFile.exists()) {
        try {
          await _snapshotFile.delete();
        } catch (_) {}
      }
      await temp.rename(_snapshotFile.path);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }

    // Mirror to legacy index files for compatibility
    await _writeAtomicJson(_idempotencyFile, state.idempotency);
    await _writeAtomicJson(_pendingFile, state.pending.toList());
    await _writeAtomicJson(
        _processingFile,
        state.processing
            .map((k, v) => MapEntry(k, v.toUtc().toIso8601String())));
  }

  Future<_QueueState> _rebuildStateFromDisk() async {
    final all = await _allJobs();
    final newIdempotency = <String, String>{};
    final newPending = <String>{};
    final newProcessing = <String, DateTime>{};
    var maxEpoch = 0;

    for (final job in all) {
      if (job.fencingEpoch != null && job.fencingEpoch! > maxEpoch) {
        maxEpoch = job.fencingEpoch!;
      }
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

    return _QueueState(
      idempotency: newIdempotency,
      pending: newPending,
      processing: newProcessing,
      currentEpoch: maxEpoch,
      lastSeq: 0,
    );
  }

  Future<_QueueIndexData> _loadLegacyIndexes() async {
    await _indexesDir.create(recursive: true);
    final idempotencyMap = <String, String>{};
    if (await _idempotencyFile.exists()) {
      try {
        final decoded =
            jsonDecode(await _idempotencyFile.readAsString()) as Map;
        for (final entry in decoded.entries) {
          idempotencyMap[entry.key as String] = entry.value as String;
        }
      } catch (_) {}
    }

    final pendingList = <String>[];
    if (await _pendingFile.exists()) {
      try {
        final decoded = jsonDecode(await _pendingFile.readAsString()) as List;
        for (final item in decoded) {
          pendingList.add(item as String);
        }
      } catch (_) {}
    }

    final processingMap = <String, DateTime>{};
    if (await _processingFile.exists()) {
      try {
        final decoded = jsonDecode(await _processingFile.readAsString()) as Map;
        for (final entry in decoded.entries) {
          processingMap[entry.key as String] =
              DateTime.parse(entry.value as String);
        }
      } catch (_) {}
    }

    return _QueueIndexData(
      idempotency: idempotencyMap,
      pending: pendingList,
      processing: processingMap,
    );
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
    RandomAccessFile? handle;
    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        handle = await file.open(mode: FileMode.append);
        await handle.lock(FileLock.blockingExclusive);
        break;
      } on PathAccessException {
        await handle?.close();
        handle = null;
        if (attempt == 24) rethrow;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
    try {
      return await action();
    } finally {
      if (handle != null) {
        try {
          await handle.unlock();
        } catch (_) {}
        await handle.close();
      }
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

class _QueueState {
  _QueueState({
    required this.idempotency,
    required this.pending,
    required this.processing,
    this.currentEpoch = 0,
    this.lastSeq = 0,
  });

  final Map<String, String> idempotency;
  final Set<String> pending;
  final Map<String, DateTime> processing;
  int currentEpoch;
  int lastSeq;
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
    this.heartbeatInterval,
    this.leaseDuration = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock;

  final RegenerationQueue queue;
  final Future<void> Function(RegenerationJob job) handle;
  final String errorCode;
  final Duration? heartbeatInterval;
  final Duration leaseDuration;
  final DateTime Function()? _clock;

  Future<RegenerationWorkerResult> processNext({DateTime? now}) async {
    final effectiveNow = now ?? _clock?.call();
    final job = await queue.claimNext(now: effectiveNow, lease: leaseDuration);
    if (job == null) return RegenerationWorkerResult.idle;
    final token = job.leaseToken;
    if (token == null) return RegenerationWorkerResult.leaseLost;

    Timer? heartbeatTimer;
    var leaseLost = false;

    final interval = heartbeatInterval ??
        (leaseDuration > const Duration(seconds: 4)
            ? Duration(milliseconds: leaseDuration.inMilliseconds ~/ 2)
            : null);

    if (interval != null) {
      heartbeatTimer = Timer.periodic(interval, (_) async {
        try {
          await queue.renewLease(
            job.id,
            leaseToken: token,
            extension: leaseDuration,
            now: _clock?.call(),
          );
        } on Object {
          leaseLost = true;
          heartbeatTimer?.cancel();
        }
      });
    }

    try {
      await handle(job);
      if (leaseLost) {
        return RegenerationWorkerResult.leaseLost;
      }
      await queue.complete(job.id, leaseToken: token);
      return RegenerationWorkerResult.completed;
    } on Object {
      if (leaseLost) {
        return RegenerationWorkerResult.leaseLost;
      }
      try {
        final failed = await queue.fail(
          job.id,
          leaseToken: token,
          errorCode: errorCode,
          now: _clock?.call() ?? now,
        );
        return failed.status == RegenerationJobStatus.failed
            ? RegenerationWorkerResult.failed
            : RegenerationWorkerResult.retryScheduled;
      } on StateError {
        return RegenerationWorkerResult.leaseLost;
      }
    } finally {
      heartbeatTimer?.cancel();
    }
  }
}
