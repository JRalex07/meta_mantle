import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One bounded page returned by a dynamic route source.
enum InitialGenerationPolicy { all, selected, none }

class RouteDiscoveryPage<T> {
  const RouteDiscoveryPage({required this.records, this.nextCursor});
  final List<T> records;
  final String? nextCursor;
}

/// Paginated data source for a route pattern containing exactly one `:key`.
class CollectionRouteSource<T> {
  const CollectionRouteSource({
    required this.routeId,
    required this.pathPattern,
    required this.discover,
    required this.keyOf,
    required this.render,
    this.tagsOf,
    this.versionOf,
    this.initialGenerationPolicy = InitialGenerationPolicy.all,
    this.includeInInitialGeneration,
    this.onProgress,
    this.isCancelled,
    this.pageSize = 100,
    this.concurrency = 4,
    this.maxRecords = 100000,
  });
  final String routeId;
  final String pathPattern;
  final Future<RouteDiscoveryPage<T>> Function(String? cursor, int limit)
  discover;
  final String Function(T record) keyOf;
  final Future<GeneratedRouteDocument> Function(T record, String path) render;
  final Iterable<String> Function(T record)? tagsOf;
  final String? Function(T record)? versionOf;
  final InitialGenerationPolicy initialGenerationPolicy;
  final bool Function(T record)? includeInInitialGeneration;
  final void Function(int discovered, int generated, int skipped)? onProgress;
  final bool Function()? isCancelled;
  final int pageSize;
  final int concurrency;
  final int maxRecords;
}

/// One fixed page rendered through the same artifact and dependency pipeline.
class FixedRouteSource {
  const FixedRouteSource({
    required this.routeId,
    required this.path,
    required this.render,
  });

  final String routeId;
  final String path;
  final Future<GeneratedRouteDocument> Function() render;
}

/// Complete HTML plus dependency information for one generated page.
class GeneratedRouteDocument {
  const GeneratedRouteDocument({
    this.tags = const [],
    this.sourceVersion,
    this.lastModified,
    this.canonicalUrl,
    this.indexable,
    required this.html,
  });
  final String html;
  final List<String> tags;
  final String? sourceVersion;
  final DateTime? lastModified;
  final String? canonicalUrl;
  final bool? indexable;
}

class RouteDependency {
  const RouteDependency({
    required this.path,
    required this.routeId,
    required this.tags,
    required this.generatedAt,
    this.sourceVersion,
    this.lastModified,
    this.canonicalUrl,
    this.indexable = true,
  });
  final String path;
  final String routeId;
  final List<String> tags;
  final DateTime generatedAt;
  final String? sourceVersion;
  final DateTime? lastModified;
  final String? canonicalUrl;
  final bool indexable;
  Map<String, Object?> toJson() => {
    'path': path,
    'routeId': routeId,
    'tags': tags,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'sourceVersion': sourceVersion,
    'lastModified': lastModified?.toUtc().toIso8601String(),
    'canonicalUrl': canonicalUrl,
    'indexable': indexable,
  };
  factory RouteDependency.fromJson(Map<String, Object?> json) =>
      RouteDependency(
        path: json['path']! as String,
        routeId: json['routeId']! as String,
        tags: (json['tags']! as List).cast<String>(),
        generatedAt: DateTime.parse(json['generatedAt']! as String),
        sourceVersion: json['sourceVersion'] as String?,
        lastModified: json['lastModified'] == null
            ? null
            : DateTime.parse(json['lastModified']! as String),
        canonicalUrl: json['canonicalUrl'] as String?,
        indexable: json['indexable'] as bool? ?? true,
      );
}

/// Consistent view of an artifact and dependency read from one publication.
class PublishedHtmlArtifact {
  const PublishedHtmlArtifact({
    required this.version,
    required this.html,
    required this.dependency,
  });

  final String? version;
  final String html;
  final RouteDependency dependency;
}

/// Declares the operational capabilities of an HTML artifact store backend.
class StorageCapabilities {
  const StorageCapabilities({
    required this.supportsMutableArtifacts,
    required this.supportsAtomicPublication,
    required this.supportsVersionedArtifacts,
    required this.supportsSharedReads,
    required this.supportsDistributedLeases,
    required this.supportsPostDeploymentMutation,
    required this.supportsCacheInvalidation,
    required this.supportsGarbageCollection,
    required this.supportsImmutableObjects,
    required this.supportsRollback,
  });

  final bool supportsMutableArtifacts;
  final bool supportsAtomicPublication;
  final bool supportsVersionedArtifacts;
  final bool supportsSharedReads;
  final bool supportsDistributedLeases;
  final bool supportsPostDeploymentMutation;
  final bool supportsCacheInvalidation;
  final bool supportsGarbageCollection;
  final bool supportsImmutableObjects;
  final bool supportsRollback;

  Map<String, bool> toMap() => {
    'supportsMutableArtifacts': supportsMutableArtifacts,
    'supportsAtomicPublication': supportsAtomicPublication,
    'supportsVersionedArtifacts': supportsVersionedArtifacts,
    'supportsSharedReads': supportsSharedReads,
    'supportsDistributedLeases': supportsDistributedLeases,
    'supportsPostDeploymentMutation': supportsPostDeploymentMutation,
    'supportsCacheInvalidation': supportsCacheInvalidation,
    'supportsGarbageCollection': supportsGarbageCollection,
    'supportsImmutableObjects': supportsImmutableObjects,
    'supportsRollback': supportsRollback,
  };
}

/// Report summarizing an artifact garbage collection execution.
class GarbageCollectionReport {
  const GarbageCollectionReport({
    required this.reclaimedBytes,
    required this.deletedObjects,
    required this.retainedVersions,
    required this.deletedVersions,
    required this.duration,
  });

  final int reclaimedBytes;
  final int deletedObjects;
  final int retainedVersions;
  final int deletedVersions;
  final Duration duration;

  Map<String, Object?> toJson() => {
    'reclaimedBytes': reclaimedBytes,
    'deletedObjects': deletedObjects,
    'retainedVersions': retainedVersions,
    'deletedVersions': deletedVersions,
    'durationMs': duration.inMilliseconds,
  };
}

/// Metadata record for an immutable content-addressed route artifact.
class RouteArtifactEntry {
  const RouteArtifactEntry({
    required this.path,
    required this.objectHash,
    required this.contentLength,
    required this.generatedAt,
  });

  final String path;
  final String objectHash;
  final int contentLength;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => {
    'path': path,
    'objectHash': objectHash,
    'contentLength': contentLength,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
  };

  factory RouteArtifactEntry.fromJson(Map<String, Object?> json) =>
      RouteArtifactEntry(
        path: json['path']! as String,
        objectHash: json['objectHash']! as String,
        contentLength: json['contentLength']! as int,
        generatedAt: DateTime.parse(json['generatedAt']! as String),
      );
}

/// Local HTML artifact store with content-addressed immutable object storage,
/// atomic manifests, path containment, and instant zero-copy publication drafts.
class FileHtmlArtifactStore {
  FileHtmlArtifactStore(Directory root) : root = root.absolute;

  /// Creates an isolated local store below [root] for one trusted tenant ID.
  ///
  /// Use the same tenant ID that was resolved from an authenticated host, never
  /// an arbitrary webhook or query parameter value.
  factory FileHtmlArtifactStore.forTenant(Directory root, String tenantId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(tenantId)) {
      throw const FormatException('Invalid artifact tenant ID.');
    }
    return FileHtmlArtifactStore(
      Directory(
        '${root.absolute.path}${Platform.pathSeparator}tenants${Platform.pathSeparator}$tenantId',
      ),
    );
  }

  final Directory root;

  /// Declares the real capabilities of this local filesystem store.
  StorageCapabilities get capabilities => const StorageCapabilities(
    supportsMutableArtifacts: true,
    supportsAtomicPublication: true,
    supportsVersionedArtifacts: true,
    supportsSharedReads: true,
    supportsDistributedLeases: false,
    supportsPostDeploymentMutation: true,
    supportsCacheInvalidation: false,
    supportsGarbageCollection: true,
    supportsImmutableObjects: true,
    supportsRollback: true,
  );

  Directory get _objectsDir =>
      Directory('${root.path}${Platform.pathSeparator}.objects');

  Directory _versionDir(String version) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(version)) {
      throw const FormatException('Invalid artifact version.');
    }
    return Directory(
      '${root.path}${Platform.pathSeparator}.versions${Platform.pathSeparator}$version',
    );
  }

  Future<String?> get activeVersion async {
    final pointer = File(
      '${root.path}${Platform.pathSeparator}.active_version',
    );
    if (!await pointer.exists()) return null;
    final version = (await pointer.readAsString()).trim();
    _versionDir(version);
    return version;
  }

  /// Creates a private draft with zero HTML file copying.
  ///
  /// Unchanged artifacts are referenced from immutable content-addressed storage
  /// via the route manifest. Only metadata is inherited.
  Future<String> beginVersion() async {
    await root.create(recursive: true);
    await _objectsDir.create(recursive: true);
    final version = 'v${DateTime.now().microsecondsSinceEpoch}_$pid';
    final draft = _versionDir(version);
    await draft.create(recursive: true);
    final active = await activeVersion;
    if (active != null) {
      final current = _versionDir(active);
      if (await current.exists()) {
        // Copy only metadata and manifests. NEVER copy HTML content files!
        await _copyManifestFiles(current, draft);
      }
    } else {
      // Import artifacts created by the pre-versioned store into .objects/
      await _importLegacyFiles(root, draft);
    }
    await File('${draft.path}${Platform.pathSeparator}.base_version')
        .writeAsString(active ?? '');
    return version;
  }

  File get _publishEpochsFile =>
      File('${root.path}${Platform.pathSeparator}.publish_epochs.json');

  Future<Map<String, int>> _loadPublishEpochs() async {
    if (!await _publishEpochsFile.exists()) return {};
    try {
      final decoded =
          jsonDecode(await _publishEpochsFile.readAsString()) as Map;
      return decoded.map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePublishEpochs(Map<String, int> epochs) async {
    await _writeJsonIndex(root, '.publish_epochs.json', epochs);
  }

  Future<void> publishVersion(
    String version, {
    int? fencingEpoch,
    String? routePath,
  }) async {
    final draft = _versionDir(version);
    if (!await draft.exists()) {
      throw StateError('Artifact draft does not exist.');
    }
    final lockFile = File('${root.path}${Platform.pathSeparator}.publish.lock');
    await root.create(recursive: true);
    final lockHandle = await lockFile.open(mode: FileMode.append);
    await lockHandle.lock(FileLock.exclusive);
    final pointer = File(
      '${root.path}${Platform.pathSeparator}.active_version',
    );
    final temp = File('${pointer.path}.${_nonce()}.tmp');
    try {
      if (fencingEpoch != null) {
        final epochs = await _loadPublishEpochs();
        final epochKey = routePath != null ? _normalizePath(routePath) : '*';
        final currentEpoch = epochs[epochKey] ?? epochs['*'] ?? 0;
        if (fencingEpoch < currentEpoch) {
          throw StaleFencingEpochException(
            fencingEpoch,
            currentEpoch,
            routePath: routePath,
          );
        }
        epochs[epochKey] = fencingEpoch;
        if (fencingEpoch > (epochs['*'] ?? 0)) {
          epochs['*'] = fencingEpoch;
        }
        await _savePublishEpochs(epochs);
      }

      final baseFile = File(
        '${draft.path}${Platform.pathSeparator}.base_version',
      );
      final expectedBase = await baseFile.exists()
          ? (await baseFile.readAsString()).trim()
          : '';
      final current = await activeVersion ?? '';
      if (current != expectedBase) {
        throw StaleArtifactVersionException(expectedBase, current);
      }

      await temp.writeAsString(version, flush: true);
      // Replace through rename without unlinking the old pointer first.
      await temp.rename(pointer.path);
    } finally {
      if (await temp.exists()) await temp.delete();
      await lockHandle.unlock();
      await lockHandle.close();
    }
  }

  /// Rolls back publication atomically to a previous valid generation.
  Future<void> rollbackTo(String targetVersion) async {
    final targetDir = _versionDir(targetVersion);
    if (!await targetDir.exists()) {
      throw ArgumentError(
        'Target rollback version "$targetVersion" does not exist.',
      );
    }
    final lockFile = File('${root.path}${Platform.pathSeparator}.publish.lock');
    await root.create(recursive: true);
    final lockHandle = await lockFile.open(mode: FileMode.append);
    await lockHandle.lock(FileLock.exclusive);
    final pointer = File(
      '${root.path}${Platform.pathSeparator}.active_version',
    );
    final temp = File('${pointer.path}.${_nonce()}.tmp');
    try {
      await temp.writeAsString(targetVersion, flush: true);
      await temp.rename(pointer.path);
    } finally {
      if (await temp.exists()) await temp.delete();
      await lockHandle.unlock();
      await lockHandle.close();
    }
  }

  Future<void> discardVersion(String version) async {
    final draft = _versionDir(version);
    if (await draft.exists()) await draft.delete(recursive: true);
  }

  String _shardKey(String path) {
    final norm = _normalizePath(path);
    final bytes = sha256.convert(utf8.encode(norm)).bytes;
    return bytes[0].toRadixString(16).padLeft(2, '0');
  }

  Directory _routeShardsDir(Directory dir) =>
      Directory('${dir.path}${Platform.pathSeparator}.route_shards');

  Directory _depShardsDir(Directory dir) =>
      Directory('${dir.path}${Platform.pathSeparator}.dep_shards');

  Future<RouteArtifactEntry?> _findRouteArtifact(
    Directory dir,
    String path,
  ) async {
    final shardsDir = _routeShardsDir(dir);
    if (await shardsDir.exists()) {
      final key = _shardKey(path);
      final file = File('${shardsDir.path}${Platform.pathSeparator}$key.json');
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString()) as Map;
          final val = decoded[path];
          if (val != null) {
            return RouteArtifactEntry.fromJson(
              Map<String, Object?>.from(val as Map),
            );
          }
        } catch (_) {}
      }
      return null;
    }
    final all = await _loadRouteArtifacts(dir);
    return all[path];
  }

  Future<void> _saveRouteArtifactShard(
    Directory dir,
    String path,
    RouteArtifactEntry entry,
  ) async {
    final shardsDir = _routeShardsDir(dir);
    await shardsDir.create(recursive: true);
    final key = _shardKey(path);
    final file = File('${shardsDir.path}${Platform.pathSeparator}$key.json');
    final map = <String, Map<String, Object?>>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString()) as Map;
        for (final e in decoded.entries) {
          map[e.key as String] = Map<String, Object?>.from(e.value as Map);
        }
      } catch (_) {}
    }
    map[path] = entry.toJson();
    await _writeJsonFile(file, map);
  }

  Future<RouteDependency?> _findRouteDependency(
    Directory dir,
    String path,
  ) async {
    final shardsDir = _depShardsDir(dir);
    if (await shardsDir.exists()) {
      final key = _shardKey(path);
      final file = File('${shardsDir.path}${Platform.pathSeparator}$key.json');
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString()) as Map;
          final val = decoded[path];
          if (val != null) {
            return RouteDependency.fromJson(
              Map<String, Object?>.from(val as Map),
            );
          }
        } catch (_) {}
      }
      return null;
    }
    final all = await _loadIndex(dir);
    return all[path];
  }

  Future<void> _saveRouteDependencyShard(
    Directory dir,
    String path,
    RouteDependency dep,
  ) async {
    final shardsDir = _depShardsDir(dir);
    await shardsDir.create(recursive: true);
    final key = _shardKey(path);
    final file = File('${shardsDir.path}${Platform.pathSeparator}$key.json');
    final map = <String, Map<String, Object?>>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString()) as Map;
        for (final e in decoded.entries) {
          map[e.key as String] = Map<String, Object?>.from(e.value as Map);
        }
      } catch (_) {}
    }
    map[path] = dep.toJson();
    await _writeJsonFile(file, map);
  }

  Future<void> _cleanAndWriteShards(
    Directory shardsDir,
    Map<String, Map<String, Map<String, Object?>>> newShards,
    Set<String> validPaths,
  ) async {
    await shardsDir.create(recursive: true);
    final touchedKeys = <String>{...newShards.keys};
    if (await shardsDir.exists()) {
      await for (final entity in shardsDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final shardName = entity.uri.pathSegments.last;
          final key = shardName.substring(0, shardName.length - 5);
          try {
            final decoded = jsonDecode(await entity.readAsString()) as Map;
            final map = <String, Map<String, Object?>>{};
            for (final e in decoded.entries) {
              if (validPaths.contains(e.key)) {
                map[e.key as String] = Map<String, Object?>.from(
                  e.value as Map,
                );
              }
            }
            if (newShards.containsKey(key)) {
              map.addAll(newShards[key]!);
            }
            if (map.isEmpty) {
              await entity.delete();
            } else {
              await _writeJsonFile(entity, map);
            }
            touchedKeys.remove(key);
          } catch (_) {}
        }
      }
    }
    for (final key in touchedKeys) {
      final file = File('${shardsDir.path}${Platform.pathSeparator}$key.json');
      await _writeJsonFile(file, newShards[key]!);
    }
  }

  Future<void> _writeJsonFile(File file, Object value) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${_nonce()}.tmp');
    try {
      await temp.writeAsString(jsonEncode(value), flush: true);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> writeVersion(String version, String path, String html) async {
    final normPath = _normalizePath(path);
    final hash = sha256.convert(utf8.encode(html)).toString();
    await _objectsDir.create(recursive: true);
    final objFile = File(
      '${_objectsDir.path}${Platform.pathSeparator}$hash.html',
    );
    if (!await objFile.exists()) {
      await _writeFile(objFile, html);
    }
    final draft = _versionDir(version);
    // Write direct path file for this specific route for concurrency and fast read
    await _writeFile(_artifactFile(draft, normPath), html);

    // Write sharded route entry
    final entry = RouteArtifactEntry(
      path: normPath,
      objectHash: hash,
      contentLength: utf8.encode(html).length,
      generatedAt: DateTime.now().toUtc(),
    );
    await _saveRouteArtifactShard(draft, normPath, entry);
  }

  Future<String?> readVersion(String version, String path) async {
    final normPath = _normalizePath(path);
    final draft = _versionDir(version);
    final file = _artifactFile(draft, normPath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    final entry = await _findRouteArtifact(draft, normPath);
    if (entry != null) {
      final objFile = File(
        '${_objectsDir.path}${Platform.pathSeparator}${entry.objectHash}.html',
      );
      if (await objFile.exists()) {
        return await objFile.readAsString();
      }
    }
    return null;
  }

  Future<void> deleteVersion(String version, String path) async {
    final normPath = _normalizePath(path);
    final draft = _versionDir(version);
    final file = _artifactFile(draft, normPath);
    if (await file.exists()) await file.delete();

    final key = _shardKey(normPath);
    final routeShard = File(
      '${_routeShardsDir(draft).path}${Platform.pathSeparator}$key.json',
    );
    if (await routeShard.exists()) {
      try {
        final decoded = jsonDecode(await routeShard.readAsString()) as Map;
        final map = Map<String, Object?>.from(decoded);
        if (map.remove(normPath) != null) {
          if (map.isEmpty) {
            await routeShard.delete();
          } else {
            await _writeJsonFile(routeShard, map);
          }
        }
      } catch (_) {}
    }

    final depShard = File(
      '${_depShardsDir(draft).path}${Platform.pathSeparator}$key.json',
    );
    if (await depShard.exists()) {
      try {
        final decoded = jsonDecode(await depShard.readAsString()) as Map;
        final map = Map<String, Object?>.from(decoded);
        if (map.remove(normPath) != null) {
          if (map.isEmpty) {
            await depShard.delete();
          } else {
            await _writeJsonFile(depShard, map);
          }
        }
      } catch (_) {}
    }

    final entries = await _loadRouteArtifacts(draft);
    if (entries.remove(normPath) != null) {
      await _saveRouteArtifacts(draft, entries);
    }
  }

  Future<Map<String, RouteDependency>> loadVersionDependencies(
    String version,
  ) async => _loadIndex(_versionDir(version));

  /// Incrementally saves or updates a single route dependency in [version]
  /// shard without rewriting the entire route catalogue.
  Future<void> saveRouteDependency(String version, RouteDependency dep) async {
    final normPath = _normalizePath(dep.path);
    final directory = _versionDir(version);
    await _saveRouteDependencyShard(directory, normPath, dep);
  }

  Future<void> saveVersionDependencies(
    String version,
    Map<String, RouteDependency> deps,
  ) async {
    final directory = _versionDir(version);
    await _saveIndex(directory, deps);

    final shardsDep = <String, Map<String, Map<String, Object?>>>{};
    final shardsRoute = <String, Map<String, Map<String, Object?>>>{};

    final entries = await _loadRouteArtifacts(directory);
    for (final dependency in deps.values) {
      final file = _artifactFile(directory, dependency.path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final hash = sha256.convert(utf8.encode(content)).toString();
        final entry = RouteArtifactEntry(
          path: dependency.path,
          objectHash: hash,
          contentLength: utf8.encode(content).length,
          generatedAt: dependency.generatedAt,
        );
        entries[dependency.path] = entry;

        final key = _shardKey(dependency.path);
        shardsRoute.putIfAbsent(key, () => {})[dependency.path] = entry
            .toJson();
      } else if (entries.containsKey(dependency.path)) {
        final existing = entries[dependency.path]!;
        final key = _shardKey(dependency.path);
        shardsRoute.putIfAbsent(key, () => {})[dependency.path] = existing
            .toJson();
      }
      final key = _shardKey(dependency.path);
      shardsDep.putIfAbsent(key, () => {})[dependency.path] = dependency
          .toJson();
    }
    entries.removeWhere((path, _) => !deps.containsKey(path));
    await _saveRouteArtifacts(directory, entries);

    final validPaths = deps.keys.toSet();
    await _cleanAndWriteShards(
      _routeShardsDir(directory),
      shardsRoute,
      validPaths,
    );
    await _cleanAndWriteShards(_depShardsDir(directory), shardsDep, validPaths);

    final reverse = <String, List<String>>{};
    final routes = <String, List<String>>{};
    for (final dependency in deps.values) {
      routes
          .putIfAbsent(dependency.routeId, () => <String>[])
          .add(dependency.path);
      for (final tag in dependency.tags.toSet()) {
        reverse.putIfAbsent(tag, () => <String>[]).add(dependency.path);
      }
    }
    for (final paths in [...reverse.values, ...routes.values]) {
      paths.sort();
    }
    await _writeJsonIndex(directory, '.meta_mantle_reverse_index.json', {
      'tags': reverse,
      'routes': routes,
    });
    final manifest = deps.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    await _writeJsonIndex(directory, 'route-manifest.json', {
      'routes': [
        for (final dependency in manifest)
          {
            'path': dependency.path,
            'routeId': dependency.routeId,
            'canonicalUrl': dependency.canonicalUrl,
            'indexable': dependency.indexable,
            'generatedAt': dependency.generatedAt.toUtc().toIso8601String(),
            'lastModified': dependency.lastModified?.toUtc().toIso8601String(),
          },
      ],
    });
  }

  Future<void> writeVersionSitemap(
    String version,
    Iterable<RouteDependency> dependencies,
  ) async {
    final entries = dependencies.where((item) => item.indexable).toList()
      ..sort(
        (a, b) =>
            (a.canonicalUrl ?? a.path).compareTo(b.canonicalUrl ?? b.path),
      );
    final xml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );
    final canonicalUrls = <String>{};
    for (final entry in entries) {
      final canonical = entry.canonicalUrl;
      if (canonical == null) continue;
      final uri = Uri.tryParse(canonical);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.hasFragment ||
          uri.hasQuery ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid canonical URL in sitemap.');
      }
      if (!canonicalUrls.add(uri.toString())) {
        throw StateError('Duplicate canonical URL in sitemap.');
      }
      xml.write('<url><loc>${_xmlEscape(uri.toString())}</loc>');
      final modified = entry.lastModified ?? entry.generatedAt;
      xml.write('<lastmod>${modified.toUtc().toIso8601String()}</lastmod>');
      xml.write('</url>');
    }
    xml.write('</urlset>');
    await _writeFile(
      File('${_versionDir(version).path}${Platform.pathSeparator}sitemap.xml'),
      xml.toString(),
    );
  }

  Future<String?> readVersionSitemap(String version) async {
    final file = File(
      '${_versionDir(version).path}${Platform.pathSeparator}sitemap.xml',
    );
    return await file.exists() ? file.readAsString() : null;
  }

  /// Copies the current complete publication to a new static-host directory.
  /// [destination] must not exist and must not overlap the artifact store.
  Future<void> exportActiveVersion(Directory destination) async {
    final active = await activeVersion;
    if (active == null) throw StateError('No artifact version is published.');
    final source = _versionDir(active).absolute;
    final target = destination.absolute;
    final sourcePath = _normalizedFileSystemPath(source.path);
    final targetPath = _normalizedFileSystemPath(target.path);
    final rootPath = _normalizedFileSystemPath(root.absolute.path);
    if (_isSameOrInside(sourcePath, targetPath) ||
        _isSameOrInside(targetPath, sourcePath) ||
        _isSameOrInside(targetPath, rootPath) ||
        _isSameOrInside(rootPath, targetPath)) {
      throw ArgumentError('Export destination must not overlap the store.');
    }
    if (await target.exists()) {
      throw StateError('Export destination already exists.');
    }
    await target.create(recursive: true);

    final entries = await _loadRouteArtifacts(source);
    if (entries.isNotEmpty) {
      for (final entry in entries.values) {
        final objFile = File(
          '${_objectsDir.path}${Platform.pathSeparator}${entry.objectHash}.html',
        );
        if (await objFile.exists()) {
          final content = await objFile.readAsString();
          await _writeFile(_artifactFile(target, entry.path), content);
        }
      }
      final sitemap = File(
        '${source.path}${Platform.pathSeparator}sitemap.xml',
      );
      if (await sitemap.exists()) {
        await sitemap.copy(
          '${target.path}${Platform.pathSeparator}sitemap.xml',
        );
      }
      final manifest = File(
        '${source.path}${Platform.pathSeparator}route-manifest.json',
      );
      if (await manifest.exists()) {
        await manifest.copy(
          '${target.path}${Platform.pathSeparator}route-manifest.json',
        );
      }
    } else {
      await _copyPublicDirectory(source, target);
    }
  }

  /// Collects unreachable objects and cleans old versions while protecting active and rollback versions.
  Future<GarbageCollectionReport> garbageCollect({
    Duration retentionGracePeriod = const Duration(minutes: 15),
    int maxRetainedVersions = 10,
  }) async {
    final watch = Stopwatch()..start();
    final lockFile = File('${root.path}${Platform.pathSeparator}.publish.lock');
    await root.create(recursive: true);
    final lockHandle = await lockFile.open(mode: FileMode.append);
    await lockHandle.lock(FileLock.exclusive);
    try {
      final active = await activeVersion;
      final versionsDir = Directory(
        '${root.path}${Platform.pathSeparator}.versions',
      );
      final allVersions = <Directory>[];
      if (await versionsDir.exists()) {
        await for (final entity in versionsDir.list(followLinks: false)) {
          if (entity is Directory) allVersions.add(entity);
        }
      }
      allVersions.sort((a, b) => b.path.compareTo(a.path));

      final retainedVersions = <String>{};
      if (active != null) retainedVersions.add(active);
      for (final v in allVersions) {
        final vName = v.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (retainedVersions.length < maxRetainedVersions) {
          retainedVersions.add(vName);
        }
      }

      final reachableHashes = <String>{};
      for (final vName in retainedVersions) {
        final vDir = _versionDir(vName);
        if (await vDir.exists()) {
          final entries = await _loadRouteArtifacts(vDir);
          reachableHashes.addAll(entries.values.map((e) => e.objectHash));
        }
      }

      var reclaimedBytes = 0;
      var deletedObjects = 0;
      final now = DateTime.now();

      if (await _objectsDir.exists()) {
        await for (final entity in _objectsDir.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.html')) continue;
          final fileName = entity.uri.pathSegments.last;
          final hash = fileName.replaceAll('.html', '');
          if (!reachableHashes.contains(hash)) {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > retentionGracePeriod) {
              reclaimedBytes += stat.size;
              await entity.delete();
              deletedObjects++;
            }
          }
        }
      }

      var deletedVersions = 0;
      for (final v in allVersions) {
        final vName = v.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!retainedVersions.contains(vName) && vName != active) {
          await v.delete(recursive: true);
          deletedVersions++;
        }
      }

      return GarbageCollectionReport(
        reclaimedBytes: reclaimedBytes,
        deletedObjects: deletedObjects,
        retainedVersions: retainedVersions.length,
        deletedVersions: deletedVersions,
        duration: watch.elapsed,
      );
    } finally {
      await lockHandle.unlock();
      await lockHandle.close();
    }
  }

  Future<List<String>> loadVersionTagPaths(String version, String tag) async {
    return _loadReversePaths(version, 'tags', tag);
  }

  Future<List<String>> loadVersionRoutePaths(String version, String routeId) =>
      _loadReversePaths(version, 'routes', routeId);

  Future<List<String>> _loadReversePaths(
    String version,
    String kind,
    String key,
  ) async {
    final file = File(
      '${_versionDir(version).path}${Platform.pathSeparator}'
      '.meta_mantle_reverse_index.json',
    );
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map;
      final index = decoded[kind] as Map?;
      return List<String>.from(index?[key] as List? ?? const []);
    } on Object {
      throw const FormatException('Hybrid tag index is corrupt.');
    }
  }

  Future<void> write(String path, String html) async {
    final active = await activeVersion;
    if (active != null) {
      await writeVersion(active, path, html);
    } else {
      final normPath = _normalizePath(path);
      final hash = sha256.convert(utf8.encode(html)).toString();
      await _objectsDir.create(recursive: true);
      final objFile = File(
        '${_objectsDir.path}${Platform.pathSeparator}$hash.html',
      );
      if (!await objFile.exists()) {
        await _writeFile(objFile, html);
      }
      final entries = await _loadRouteArtifacts(root);
      entries[normPath] = RouteArtifactEntry(
        path: normPath,
        objectHash: hash,
        contentLength: utf8.encode(html).length,
        generatedAt: DateTime.now().toUtc(),
      );
      await _saveRouteArtifacts(root, entries);
      await _writeFile(_file(path), html);
    }
  }

  Future<String?> read(String path) async {
    final active = await activeVersion;
    if (active != null) return readVersion(active, path);
    final normPath = _normalizePath(path);
    final entries = await _loadRouteArtifacts(root);
    final entry = entries[normPath];
    if (entry != null) {
      final objFile = File(
        '${_objectsDir.path}${Platform.pathSeparator}${entry.objectHash}.html',
      );
      if (await objFile.exists()) return await objFile.readAsString();
    }
    final file = _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  /// Reads HTML and its dependency record from the same active version.
  Future<PublishedHtmlArtifact?> readPublished(String path) async {
    final version = await activeVersion;
    final dir = version == null ? root : _versionDir(version);
    final normPath = _normalizePath(path);
    final dependency = await _findRouteDependency(dir, normPath);
    if (dependency == null) return null;
    final html = version == null
        ? await _readLegacy(path)
        : await readVersion(version, path);
    if (html == null) return null;
    return PublishedHtmlArtifact(
      version: version,
      html: html,
      dependency: dependency,
    );
  }

  Future<String?> _readLegacy(String path) async {
    final file = _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> delete(String path) async {
    final active = await activeVersion;
    if (active != null) return deleteVersion(active, path);
    final normPath = _normalizePath(path);
    final entries = await _loadRouteArtifacts(root);
    entries.remove(normPath);
    await _saveRouteArtifacts(root, entries);
    final file = _file(path);
    if (await file.exists()) await file.delete();
  }

  Future<Map<String, RouteDependency>> loadDependencies() async {
    final active = await activeVersion;
    if (active != null) return loadVersionDependencies(active);
    return _loadIndex(root);
  }

  Future<Map<String, RouteDependency>> _loadIndex(Directory directory) async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}.meta_mantle_dependencies.json',
    );
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map;
      return decoded.map(
        (k, v) => MapEntry(
          k as String,
          RouteDependency.fromJson(Map<String, Object?>.from(v as Map)),
        ),
      );
    } on Object {
      throw const FormatException('Hybrid dependency index is corrupt.');
    }
  }

  Future<void> saveDependencies(Map<String, RouteDependency> deps) async {
    await _saveIndex(root, deps);
  }

  Future<void> _saveIndex(
    Directory directory,
    Map<String, RouteDependency> deps,
  ) async {
    await _writeJsonIndex(
      directory,
      '.meta_mantle_dependencies.json',
      deps.map((k, v) => MapEntry(k, v.toJson())),
    );
  }

  Future<Map<String, RouteArtifactEntry>> _loadRouteArtifacts(
    Directory directory,
  ) async {
    final file = File(
      '${directory.path}${Platform.pathSeparator}.route_artifacts.json',
    );
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map;
      return decoded.map(
        (k, v) => MapEntry(
          k as String,
          RouteArtifactEntry.fromJson(Map<String, Object?>.from(v as Map)),
        ),
      );
    } on Object {
      throw const FormatException('Route artifacts manifest is corrupt.');
    }
  }

  Future<void> _saveRouteArtifacts(
    Directory directory,
    Map<String, RouteArtifactEntry> entries,
  ) async {
    await _writeJsonIndex(
      directory,
      '.route_artifacts.json',
      entries.map((k, v) => MapEntry(k, v.toJson())),
    );
  }

  Future<void> _writeJsonIndex(
    Directory directory,
    String name,
    Object value,
  ) async {
    await directory.create(recursive: true);
    final path = '${directory.path}${Platform.pathSeparator}$name';
    final target = File(path);
    final temp = File('$path.${_nonce()}.tmp');
    try {
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(value),
        flush: true,
      );
      if (await target.exists()) {
        try {
          await target.delete();
        } catch (_) {}
      }
      await temp.rename(path);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  File _file(String routePath) {
    return _artifactFile(root, routePath);
  }

  File _artifactFile(Directory directory, String routePath) {
    final path = _normalizePath(routePath);
    final relative = path == '/'
        ? 'index.html'
        : '${path.substring(1)}/index.html';
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}$relative',
    ).absolute;
    final prefix = directory.path.endsWith(Platform.pathSeparator)
        ? directory.path
        : '${directory.path}${Platform.pathSeparator}';
    if (!candidate.path.startsWith(prefix)) {
      throw const FormatException('Artifact path escapes its root.');
    }
    return candidate;
  }

  Future<void> _copyManifestFiles(Directory from, Directory to) async {
    const manifestNames = {
      '.route_artifacts.json',
      '.meta_mantle_dependencies.json',
      '.meta_mantle_reverse_index.json',
      'route-manifest.json',
      'sitemap.xml',
    };
    for (final name in manifestNames) {
      final src = File('${from.path}${Platform.pathSeparator}$name');
      if (await src.exists()) {
        await src.copy('${to.path}${Platform.pathSeparator}$name');
      }
    }

    const shardDirs = {'.route_shards', '.dep_shards'};
    for (final dirName in shardDirs) {
      final srcDir = Directory('${from.path}${Platform.pathSeparator}$dirName');
      if (await srcDir.exists()) {
        final destDir = Directory(
          '${to.path}${Platform.pathSeparator}$dirName',
        );
        await destDir.create(recursive: true);
        await for (final entity in srcDir.list(followLinks: false)) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last;
            await entity.copy(
              '${destDir.path}${Platform.pathSeparator}$fileName',
            );
          }
        }
      }
    }
  }

  Future<void> _copyPublicDirectory(Directory from, Directory to) async {
    await for (final entity in from.list(followLinks: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name.startsWith('.')) continue;
      final dest = '${to.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        final child = Directory(dest)..createSync(recursive: true);
        await _copyPublicDirectory(entity, child);
      } else if (entity is File) {
        await entity.copy(dest);
      }
    }
  }

  Future<void> _importLegacyFiles(Directory from, Directory to) async {
    final entries = <String, RouteArtifactEntry>{};
    if (await from.exists()) {
      await for (final entity in from.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.html')) continue;
        final rel = entity.path
            .substring(from.path.length)
            .replaceAll('\\', '/');
        if (rel.startsWith('/.objects') ||
            rel.startsWith('/.versions') ||
            rel.startsWith('/tenants')) {
          continue;
        }
        final routePath = rel == '/index.html'
            ? '/'
            : (rel.endsWith('/index.html')
                  ? rel.substring(0, rel.length - '/index.html'.length)
                  : rel.substring(0, rel.length - '.html'.length));
        final content = await entity.readAsString();
        final hash = sha256.convert(utf8.encode(content)).toString();
        final objFile = File(
          '${_objectsDir.path}${Platform.pathSeparator}$hash.html',
        );
        if (!await objFile.exists()) {
          await _writeFile(objFile, content);
        }
        entries[routePath] = RouteArtifactEntry(
          path: routePath,
          objectHash: hash,
          contentLength: utf8.encode(content).length,
          generatedAt: DateTime.now().toUtc(),
        );
        await _writeFile(_artifactFile(to, routePath), content);
      }
    }
    if (entries.isNotEmpty) {
      await _saveRouteArtifacts(to, entries);
    }
    final depsFile = File(
      '${from.path}${Platform.pathSeparator}.meta_mantle_dependencies.json',
    );
    if (await depsFile.exists()) {
      await depsFile.copy(
        '${to.path}${Platform.pathSeparator}.meta_mantle_dependencies.json',
      );
    }
  }

  Future<void> _writeFile(File file, String content) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${_nonce()}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }
}

class HybridGenerationReport {
  const HybridGenerationReport({
    required this.discovered,
    required this.generated,
    required this.pages,
    this.skipped = 0,
    this.deleted = 0,
    this.siteId = 'default',
    this.buildId,
    this.startedAt,
    this.completedAt,
  });

  final int discovered;
  final int generated;
  final List<String> pages;
  final int skipped;
  final int deleted;
  final String siteId;
  final String? buildId;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Duration? get duration => startedAt == null || completedAt == null
      ? null
      : completedAt!.difference(startedAt!);

  Map<String, Object?> toJson() => {
    'buildId': buildId,
    'siteId': siteId,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'durationMs': duration?.inMilliseconds,
    'discovered': discovered,
    'generated': generated,
    'skipped': skipped,
    'deleted': deleted,
    'pages': pages,
  };
}

/// Generates paginated collections without loading all records at once.
class HybridStaticGenerator {
  HybridStaticGenerator({
    required this.store,
    this.siteBaseUrl,
    this.siteId = 'default',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (siteBaseUrl != null) _validateBaseUrl(siteBaseUrl!);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(siteId)) {
      throw ArgumentError.value(siteId, 'siteId', 'Must be a safe identifier.');
    }
  }
  final FileHtmlArtifactStore store;
  final String? siteBaseUrl;
  final String siteId;
  final DateTime Function() _clock;

  Future<HybridGenerationReport> generate<T>(
    CollectionRouteSource<T> source,
  ) async {
    if (source.pageSize < 1 ||
        source.pageSize > 1000 ||
        source.concurrency < 1 ||
        source.concurrency > 32 ||
        source.maxRecords < 1 ||
        source.maxRecords > 1000000) {
      throw ArgumentError('Page size or concurrency is out of bounds.');
    }
    if (source.routeId.trim().isEmpty) {
      throw ArgumentError('routeId is required.');
    }
    if (':key'.allMatches(source.pathPattern).length != 1) {
      throw ArgumentError('pathPattern must contain exactly one :key.');
    }
    if (source.initialGenerationPolicy == InitialGenerationPolicy.selected &&
        source.includeInInitialGeneration == null) {
      throw ArgumentError(
        'selected generation requires includeInInitialGeneration.',
      );
    }
    _normalizePath(source.pathPattern.replaceAll(':key', 'placeholder'));
    final startedAt = _clock().toUtc();
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final oldRoutePaths = deps.values
          .where((d) => d.routeId == source.routeId)
          .map((d) => d.path)
          .toSet();
      if (source.initialGenerationPolicy == InitialGenerationPolicy.none) {
        for (final path in oldRoutePaths) {
          await store.deleteVersion(version, path);
          deps.remove(path);
        }
        await store.saveVersionDependencies(version, deps);
        await _writeSitemapIfConfigured(version, deps);
        await store.publishVersion(version);
        return HybridGenerationReport(
          discovered: 0,
          generated: 0,
          pages: const [],
          deleted: oldRoutePaths.length,
          siteId: siteId,
          buildId: version,
          startedAt: startedAt,
          completedAt: _clock().toUtc(),
        );
      }
      final keys = <String>{}, pages = <String>[];
      final cursors = <String>{};
      var discovered = 0;
      var skipped = 0;
      String? cursor;
      do {
        if (source.isCancelled?.call() == true) {
          throw StateError('Collection generation was cancelled.');
        }
        final page = await source.discover(cursor, source.pageSize);
        if (page.records.length > source.pageSize) {
          throw StateError('Source exceeded requested page size.');
        }
        discovered += page.records.length;
        if (discovered > source.maxRecords) {
          throw StateError(
            'Collection exceeded the configured maxRecords limit.',
          );
        }
        for (var i = 0; i < page.records.length; i += source.concurrency) {
          await Future.wait(
            page.records.skip(i).take(source.concurrency).map((record) async {
              final key = source.keyOf(record);
              if (key.isEmpty ||
                  key == '.' ||
                  key == '..' ||
                  key.contains('/') ||
                  key.contains('\\') ||
                  key.contains('\u0000')) {
                throw const FormatException('Invalid route key.');
              }
              if (!keys.add(key)) throw StateError('Duplicate route key.');
              if (source.initialGenerationPolicy ==
                      InitialGenerationPolicy.selected &&
                  !source.includeInInitialGeneration!(record)) {
                skipped++;
                return;
              }
              final path = _normalizePath(
                source.pathPattern.replaceAll(':key', Uri.encodeComponent(key)),
              );
              if (deps[path] != null && deps[path]!.routeId != source.routeId) {
                throw StateError('Route collision at $path.');
              }
              final document = await source.render(record, path);
              _validateCompleteDocument(document.html);
              await store.writeVersion(version, path, document.html);
              deps[path] = RouteDependency(
                path: path,
                routeId: source.routeId,
                tags: {
                  ...?source.tagsOf?.call(record),
                  ...document.tags,
                }.toList()..sort(),
                generatedAt: _clock().toUtc(),
                sourceVersion:
                    document.sourceVersion ?? source.versionOf?.call(record),
                lastModified: document.lastModified,
                canonicalUrl: document.canonicalUrl ?? _defaultCanonical(path),
                indexable: document.indexable ?? true,
              );
              pages.add(path);
            }),
          );
        }
        source.onProgress?.call(discovered, pages.length, skipped);
        if (page.nextCursor != null && !cursors.add(page.nextCursor!)) {
          throw StateError('Pagination cursor cycle detected.');
        }
        cursor = page.nextCursor;
      } while (cursor != null);
      final obsolete = oldRoutePaths.difference(pages.toSet());
      for (final path in obsolete) {
        await store.deleteVersion(version, path);
        deps.remove(path);
      }
      await store.saveVersionDependencies(version, deps);
      await _writeSitemapIfConfigured(version, deps);
      await store.publishVersion(version);
      return HybridGenerationReport(
        discovered: discovered,
        generated: pages.length,
        pages: List.unmodifiable(pages),
        skipped: skipped,
        deleted: obsolete.length,
        siteId: siteId,
        buildId: version,
        startedAt: startedAt,
        completedAt: _clock().toUtc(),
      );
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }

  Future<HybridGenerationReport> generateFixedPages(
    Iterable<FixedRouteSource> routes,
  ) async {
    final startedAt = _clock().toUtc();
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final sources = routes.toList(growable: false);
      if (sources.any((route) => route.routeId.trim().isEmpty)) {
        throw ArgumentError('routeId is required.');
      }
      final routeIds = sources.map((route) => route.routeId).toSet();
      final oldPaths = deps.values
          .where((dependency) => routeIds.contains(dependency.routeId))
          .map((dependency) => dependency.path)
          .toSet();
      final paths = <String>{};
      for (final route in sources) {
        final path = _normalizePath(route.path);
        if (!paths.add(path)) throw StateError('Duplicate fixed route path.');
        final existing = deps[path];
        if (existing != null && existing.routeId != route.routeId) {
          throw StateError('Route collision at $path.');
        }
        final document = await route.render();
        _validateCompleteDocument(document.html);
        await store.writeVersion(version, path, document.html);
        deps[path] = RouteDependency(
          path: path,
          routeId: route.routeId,
          tags: document.tags.toSet().toList()..sort(),
          generatedAt: _clock().toUtc(),
          sourceVersion: document.sourceVersion,
          lastModified: document.lastModified,
          canonicalUrl: document.canonicalUrl ?? _defaultCanonical(path),
          indexable: document.indexable ?? true,
        );
      }
      for (final obsolete in oldPaths.difference(paths)) {
        await store.deleteVersion(version, obsolete);
        deps.remove(obsolete);
      }
      await store.saveVersionDependencies(version, deps);
      await _writeSitemapIfConfigured(version, deps);
      await store.publishVersion(version);
      return HybridGenerationReport(
        discovered: sources.length,
        generated: sources.length,
        pages: List.unmodifiable(paths),
        deleted: oldPaths.difference(paths).length,
        siteId: siteId,
        buildId: version,
        startedAt: startedAt,
        completedAt: _clock().toUtc(),
      );
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }

  String? _defaultCanonical(String path) => siteBaseUrl == null
      ? null
      : Uri.parse(siteBaseUrl!).resolve(path.substring(1)).toString();

  Future<void> _writeSitemapIfConfigured(
    String version,
    Map<String, RouteDependency> dependencies,
  ) async {
    final priorSitemap = await store.readVersionSitemap(version);
    if (siteBaseUrl != null ||
        priorSitemap != null ||
        dependencies.values.any(
          (dependency) => dependency.canonicalUrl != null,
        )) {
      await store.writeVersionSitemap(version, dependencies.values);
    }
  }
}

void _validateCompleteDocument(String html) {
  final lower = html.toLowerCase();
  if (!lower.contains('<!doctype html>') || !lower.contains('<body')) {
    throw StateError('Renderer must return a complete HTML document.');
  }
}

/// Explicit in-process revalidation. It is not a durable/distributed queue.
class HybridRevalidator {
  HybridRevalidator({
    required this.store,
    required this.regenerate,
    this.compareSourceVersions,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FileHtmlArtifactStore store;
  final Future<GeneratedRouteDocument> Function(
    String path,
    RouteDependency previous,
  )
  regenerate;

  /// Compares generated and published source versions. Return a negative value
  /// when [candidate] is older than [current]. If omitted, publication is
  /// fenced by the artifact base version only.
  final int Function(String candidate, String current)? compareSourceVersions;
  final DateTime Function() _clock;

  Future<List<String>> revalidatePath(String path, {int? fencingEpoch}) async {
    final normalized = _normalizePath(path);
    return _revalidateSelection(
      (_, dependencies) async =>
          dependencies.containsKey(normalized) ? [normalized] : const [],
      fencingEpoch: fencingEpoch,
      routePath: normalized,
    );
  }

  Future<List<String>> revalidateTag(String tag) async {
    if (tag.trim().isEmpty || tag.length > 200 || tag.contains('\u0000')) {
      throw const FormatException('Invalid dependency tag.');
    }
    return _revalidateSelection(
      (version, _) => store.loadVersionTagPaths(version, tag),
    );
  }

  Future<List<String>> revalidateRoute(String routeId) async {
    if (routeId.trim().isEmpty || routeId.length > 200) {
      throw const FormatException('Invalid route ID.');
    }
    return _revalidateSelection(
      (version, _) => store.loadVersionRoutePaths(version, routeId),
    );
  }

  Future<List<String>> revalidateAll() async {
    return _revalidateSelection(
      (_, dependencies) async => dependencies.keys.toList(),
    );
  }

  Future<List<String>> deleteRoute(String routeId) async {
    if (routeId.trim().isEmpty || routeId.length > 200) {
      throw const FormatException('Invalid route ID.');
    }
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final paths =
          deps.values
              .where((dependency) => dependency.routeId == routeId)
              .map((dependency) => dependency.path)
              .toList()
            ..sort();
      if (paths.isEmpty) {
        await store.discardVersion(version);
        return const [];
      }
      for (final path in paths) {
        await store.deleteVersion(version, path);
        deps.remove(path);
      }
      await store.saveVersionDependencies(version, deps);
      if (await store.readVersionSitemap(version) != null ||
          deps.values.any((dependency) => dependency.canonicalUrl != null)) {
        await store.writeVersionSitemap(version, deps.values);
      }
      await store.publishVersion(version);
      return List.unmodifiable(paths);
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }

  Future<List<String>> _revalidateSelection(
    Future<List<String>> Function(
      String version,
      Map<String, RouteDependency> dependencies,
    )
    select, {
    int? fencingEpoch,
    String? routePath,
  }) async {
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final paths = (await select(
        version,
        deps,
      )).where(deps.containsKey).toSet().toList()..sort();
      if (paths.isEmpty) {
        await store.discardVersion(version);
        return const [];
      }
      for (final path in paths) {
        final previous = deps[path];
        if (previous == null) continue;
        final document = await regenerate(path, previous);
        _validateCompleteDocument(document.html);
        final candidateVersion =
            document.sourceVersion ?? previous.sourceVersion;
        final currentVersion = previous.sourceVersion;
        if (candidateVersion != null &&
            currentVersion != null &&
            compareSourceVersions != null &&
            compareSourceVersions!(candidateVersion, currentVersion) < 0) {
          throw StaleGeneratedDocumentException(
            path,
            candidateVersion,
            currentVersion,
          );
        }
        await store.writeVersion(version, path, document.html);
        deps[path] = RouteDependency(
          path: path,
          routeId: previous.routeId,
          tags: document.tags.toSet().toList()..sort(),
          generatedAt: _clock().toUtc(),
          sourceVersion: candidateVersion,
          lastModified: document.lastModified ?? previous.lastModified,
          canonicalUrl: document.canonicalUrl ?? previous.canonicalUrl,
          indexable: document.indexable ?? previous.indexable,
        );
      }
      await store.saveVersionDependencies(version, deps);
      if (await store.readVersionSitemap(version) != null ||
          deps.values.any((dependency) => dependency.canonicalUrl != null)) {
        await store.writeVersionSitemap(version, deps.values);
      }
      await store.publishVersion(
        version,
        fencingEpoch: fencingEpoch,
        routePath: routePath,
      );
      return List.unmodifiable(paths);
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }
}

class StaleGeneratedDocumentException implements Exception {
  const StaleGeneratedDocumentException(
    this.path,
    this.candidateVersion,
    this.currentVersion,
  );

  final String path;
  final String candidateVersion;
  final String currentVersion;

  @override
  String toString() =>
      'Generated source version for $path is older than the published version.';
}

void _validateBaseUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      !raw.endsWith('/')) {
    throw ArgumentError(
      'siteBaseUrl must be an absolute HTTP(S) URL ending in /.',
    );
  }
}

String _xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _normalizedFileSystemPath(String value) {
  var normalized = value.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');
  if (normalized.length > 1) {
    normalized = normalized.replaceFirst(RegExp(r'/$'), '');
  }
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _isSameOrInside(String path, String parent) =>
    path == parent || path.startsWith('$parent/');

String _normalizePath(String path) {
  if (!path.startsWith('/') ||
      path.contains('\\') ||
      path.contains('?') ||
      path.contains('#') ||
      path.contains('\u0000')) {
    throw const FormatException('Route path must be an absolute URL path.');
  }
  if (path.split('/').any((s) => s == '.' || s == '..')) {
    throw const FormatException('Path traversal is not allowed.');
  }
  final normalized = path.replaceAll(RegExp(r'/+'), '/');
  return normalized == '/' ? '/' : normalized.replaceFirst(RegExp(r'/$'), '');
}

String _nonce() => '${DateTime.now().microsecondsSinceEpoch}_$pid';

/// Thrown when an artifact publication attempt presents an obsolete or lower fencing epoch.
class StaleFencingEpochException implements Exception {
  const StaleFencingEpochException(
    this.candidateEpoch,
    this.currentEpoch, {
    this.routePath,
  });

  final int candidateEpoch;
  final int currentEpoch;
  final String? routePath;

  @override
  String toString() =>
      'StaleFencingEpochException: Publication with epoch $candidateEpoch was rejected because current active epoch is $currentEpoch${routePath != null ? " for route $routePath" : ""}.';
}

/// Thrown when a draft was based on a publication that is no longer active.
class StaleArtifactVersionException implements Exception {
  const StaleArtifactVersionException(this.expected, this.current);
  final String expected;
  final String current;
  @override
  String toString() =>
      'Artifact draft is stale (based on "$expected", current is "$current").';
}
