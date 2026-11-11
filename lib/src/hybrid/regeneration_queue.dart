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

/// File-backed queue for one host/shared filesystem. OS file locking protects
/// claims on filesystems that implement Dart's exclusive lock semantics. It is
/// not a distributed queue and must not be used over unverified network shares.
class FileRegenerationQueue {
  FileRegenerationQueue(Directory directory, {this.maxProcessingJobs = 4})
      : directory = directory.absolute {
    if (maxProcessingJobs < 1 || maxProcessingJobs > 128) {
      throw ArgumentError('maxProcessingJobs must be between 1 and 128.');
    }
  }
  final Directory directory;
  final int maxProcessingJobs;

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
        final existing = await _allJobs();
        for (final job in existing) {
          if (job.siteId == siteId &&
              job.tenantId == tenantId &&
              job.idempotencyKey == idempotencyKey &&
              job.status != RegenerationJobStatus.cancelled) {
            return job;
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
            availableAt: created);
        await _save(job);
        return job;
      });

  Future<RegenerationJob?> claimNext(
          {DateTime? now, Duration lease = const Duration(minutes: 2)}) async =>
      _locked(() async {
        if (lease <= Duration.zero) {
          throw ArgumentError('lease must be positive.');
        }
        final time = (now ?? DateTime.now()).toUtc();
        final jobs = await _allJobs();
        final working = <String>{};
        for (final job in jobs) {
          if (job.status == RegenerationJobStatus.processing &&
              job.leaseUntil != null &&
              job.leaseUntil!.isAfter(time)) {
            working.add('${job.siteId}|${job.tenantId}|${job.path}');
          }
        }
        for (final job in jobs.where((j) =>
            j.status == RegenerationJobStatus.processing &&
            j.leaseUntil != null &&
            !j.leaseUntil!.isAfter(time))) {
          final recovered = job.attempts >= job.maxAttempts
              ? job.copyWith(
                  status: RegenerationJobStatus.failed,
                  clearLease: true,
                  errorCode: 'worker_lease_expired')
              : job.copyWith(
                  status: RegenerationJobStatus.queued,
                  availableAt: time,
                  clearLease: true,
                  errorCode: 'worker_lease_expired');
          await _save(recovered);
        }
        final current = await _allJobs();
        if (current
                .where((j) => j.status == RegenerationJobStatus.processing)
                .length >=
            maxProcessingJobs) {
          return null;
        }
        final ready = current
            .where((j) =>
                j.status == RegenerationJobStatus.queued &&
                !j.availableAt.isAfter(time) &&
                !working.contains('${j.siteId}|${j.tenantId}|${j.path}'))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (ready.isEmpty) return null;
        final job = ready.first.copyWith(
            status: RegenerationJobStatus.processing,
            attempts: ready.first.attempts + 1,
            leaseUntil: time.add(lease),
            leaseToken: _queueNonce(),
            clearLease: false);
        await _save(job);
        return job;
      });

  Future<RegenerationJob> complete(String id, {required String leaseToken}) =>
      _update(id, (job) {
        if (job.status != RegenerationJobStatus.processing) {
          throw StateError('Only processing jobs can complete.');
        }
        _checkLeaseToken(job, leaseToken);
        return job.copyWith(
            status: RegenerationJobStatus.completed,
            clearLease: true,
            clearError: true);
      });

  Future<RegenerationJob> fail(String id,
          {required String leaseToken,
          required String errorCode,
          DateTime? now}) =>
      _update(id, (job) {
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
        return job.copyWith(
            status: exhausted
                ? RegenerationJobStatus.failed
                : RegenerationJobStatus.queued,
            availableAt: time.add(delay),
            clearLease: true,
            errorCode: errorCode);
      });

  Future<RegenerationJob> cancel(String id) => _update(id, (job) {
        if (job.status != RegenerationJobStatus.queued) {
          throw StateError('Only queued jobs can be cancelled.');
        }
        return job.copyWith(status: RegenerationJobStatus.cancelled);
      });

  Future<List<RegenerationJob>> list() => _locked(_allJobs);

  Future<RegenerationJob> _update(
          String id, RegenerationJob Function(RegenerationJob) update) =>
      _locked(() async {
        final job = await _read(id);
        final changed = update(job);
        await _save(changed);
        return changed;
      });

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

  Future<List<RegenerationJob>> _allJobs() async {
    final result = <RegenerationJob>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.job.json')) continue;
      final decoded = jsonDecode(await entity.readAsString()) as Map;
      result.add(RegenerationJob.fromJson(Map<String, Object?>.from(decoded)));
    }
    return result;
  }

  Future<RegenerationJob> _read(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(id)) {
      throw const FormatException('Invalid job ID.');
    }
    final file = File('${directory.path}${Platform.pathSeparator}$id.job.json');
    if (!await file.exists()) throw StateError('Regeneration job not found.');
    return RegenerationJob.fromJson(Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map));
  }

  Future<void> _save(RegenerationJob job) async {
    final path = '${directory.path}${Platform.pathSeparator}${job.id}.job.json';
    final temp = File('$path.${_queueNonce()}.tmp');
    try {
      await temp.writeAsString(
          const JsonEncoder.withIndent('  ').convert(job.toJson()),
          flush: true);
      await temp.rename(path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  void _validateId(String value, String name) {
    if (value.trim().isEmpty ||
        value.length > 120 ||
        value.contains('\u0000')) {
      throw ArgumentError('$name is invalid.');
    }
  }
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

String _queueNonce() => '${DateTime.now().microsecondsSinceEpoch}_$pid';

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

  final FileRegenerationQueue queue;
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
