import 'dart:convert';
import 'dart:io';

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
  const GeneratedRouteDocument(
      {this.tags = const [],
      this.sourceVersion,
      this.lastModified,
      this.canonicalUrl,
      this.indexable,
      required this.html});
  final String html;
  final List<String> tags;
  final String? sourceVersion;
  final DateTime? lastModified;
  final String? canonicalUrl;
  final bool? indexable;
}

class RouteDependency {
  const RouteDependency(
      {required this.path,
      required this.routeId,
      required this.tags,
      required this.generatedAt,
      this.sourceVersion,
      this.lastModified,
      this.canonicalUrl,
      this.indexable = true});
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

/// Local HTML artifact store with path containment and atomic replacement.
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
    return FileHtmlArtifactStore(Directory(
      '${root.absolute.path}${Platform.pathSeparator}tenants${Platform.pathSeparator}$tenantId',
    ));
  }

  final Directory root;
  Directory _versionDir(String version) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(version)) {
      throw const FormatException('Invalid artifact version.');
    }
    return Directory(
        '${root.path}${Platform.pathSeparator}.versions${Platform.pathSeparator}$version');
  }

  Future<String?> get activeVersion async {
    final pointer =
        File('${root.path}${Platform.pathSeparator}.active_version');
    if (!await pointer.exists()) return null;
    final version = (await pointer.readAsString()).trim();
    _versionDir(version);
    return version;
  }

  /// Creates a private draft copied from the active publication.
  Future<String> beginVersion() async {
    await root.create(recursive: true);
    final version = 'v${DateTime.now().microsecondsSinceEpoch}_$pid';
    final draft = _versionDir(version);
    await draft.create(recursive: true);
    final active = await activeVersion;
    if (active != null) {
      final current = _versionDir(active);
      if (await current.exists()) await _copyDirectory(current, draft);
    } else {
      // Import artifacts created by the pre-versioned experimental store.
      await _copyLegacyFiles(root, draft);
    }
    await File('${draft.path}${Platform.pathSeparator}.base_version')
        .writeAsString(active ?? '');
    return version;
  }

  Future<void> publishVersion(String version) async {
    final draft = _versionDir(version);
    if (!await draft.exists()) {
      throw StateError('Artifact draft does not exist.');
    }
    final lockFile = File('${root.path}${Platform.pathSeparator}.publish.lock');
    await root.create(recursive: true);
    final lockHandle = await lockFile.open(mode: FileMode.append);
    await lockHandle.lock(FileLock.exclusive);
    final pointer =
        File('${root.path}${Platform.pathSeparator}.active_version');
    final temp = File('${pointer.path}.${_nonce()}.tmp');
    try {
      final baseFile =
          File('${draft.path}${Platform.pathSeparator}.base_version');
      final expectedBase =
          await baseFile.exists() ? (await baseFile.readAsString()).trim() : '';
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

  Future<void> discardVersion(String version) async {
    final draft = _versionDir(version);
    if (await draft.exists()) await draft.delete(recursive: true);
  }

  Future<void> writeVersion(String version, String path, String html) async {
    await _writeFile(_artifactFile(_versionDir(version), path), html);
  }

  Future<String?> readVersion(String version, String path) async {
    final file = _artifactFile(_versionDir(version), path);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> deleteVersion(String version, String path) async {
    final file = _artifactFile(_versionDir(version), path);
    if (await file.exists()) await file.delete();
  }

  Future<Map<String, RouteDependency>> loadVersionDependencies(
          String version) async =>
      _loadIndex(_versionDir(version));

  Future<void> saveVersionDependencies(
      String version, Map<String, RouteDependency> deps) async {
    final directory = _versionDir(version);
    await _saveIndex(directory, deps);
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
      String version, Iterable<RouteDependency> dependencies) async {
    final entries = dependencies.where((item) => item.indexable).toList()
      ..sort((a, b) =>
          (a.canonicalUrl ?? a.path).compareTo(b.canonicalUrl ?? b.path));
    final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
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
        '${_versionDir(version).path}${Platform.pathSeparator}sitemap.xml');
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
    await _copyPublicDirectory(source, target);
  }

  Future<List<String>> loadVersionTagPaths(String version, String tag) async {
    return _loadReversePaths(version, 'tags', tag);
  }

  Future<List<String>> loadVersionRoutePaths(String version, String routeId) =>
      _loadReversePaths(version, 'routes', routeId);

  Future<List<String>> _loadReversePaths(
      String version, String kind, String key) async {
    final file = File('${_versionDir(version).path}${Platform.pathSeparator}'
        '.meta_mantle_reverse_index.json');
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
    await _writeFile(_file(path), html);
  }

  Future<String?> read(String path) async {
    final active = await activeVersion;
    if (active != null) return readVersion(active, path);
    final file = _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  /// Reads HTML and its dependency record from the same active version.
  Future<PublishedHtmlArtifact?> readPublished(String path) async {
    final version = await activeVersion;
    final dependencies = version == null
        ? await _loadIndex(root)
        : await loadVersionDependencies(version);
    final dependency = dependencies[_normalizePath(path)];
    if (dependency == null) return null;
    final html = version == null
        ? await _readLegacy(path)
        : await readVersion(version, path);
    if (html == null) return null;
    return PublishedHtmlArtifact(
        version: version, html: html, dependency: dependency);
  }

  Future<String?> _readLegacy(String path) async {
    final file = _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> delete(String path) async {
    final active = await activeVersion;
    if (active != null) return deleteVersion(active, path);
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
        '${directory.path}${Platform.pathSeparator}.meta_mantle_dependencies.json');
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map;
      return decoded.map((k, v) => MapEntry(k as String,
          RouteDependency.fromJson(Map<String, Object?>.from(v as Map))));
    } on Object {
      throw const FormatException('Hybrid dependency index is corrupt.');
    }
  }

  Future<void> saveDependencies(Map<String, RouteDependency> deps) async {
    await _saveIndex(root, deps);
  }

  Future<void> _saveIndex(
      Directory directory, Map<String, RouteDependency> deps) async {
    await _writeJsonIndex(directory, '.meta_mantle_dependencies.json',
        deps.map((k, v) => MapEntry(k, v.toJson())));
  }

  Future<void> _writeJsonIndex(
      Directory directory, String name, Object value) async {
    await directory.create(recursive: true);
    final path = '${directory.path}${Platform.pathSeparator}$name';
    final temp = File('$path.${_nonce()}.tmp');
    try {
      await temp.writeAsString(
          const JsonEncoder.withIndent('  ').convert(value),
          flush: true);
      await temp.rename(path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  File _file(String routePath) {
    return _artifactFile(root, routePath);
  }

  File _artifactFile(Directory directory, String routePath) {
    final path = _normalizePath(routePath);
    final relative =
        path == '/' ? 'index.html' : '${path.substring(1)}/index.html';
    final candidate =
        File('${directory.path}${Platform.pathSeparator}$relative').absolute;
    final prefix = directory.path.endsWith(Platform.pathSeparator)
        ? directory.path
        : '${directory.path}${Platform.pathSeparator}';
    if (!candidate.path.startsWith(prefix)) {
      throw const FormatException('Artifact path escapes its root.');
    }
    return candidate;
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    await for (final entity in from.list(followLinks: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final dest = '${to.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        final child = Directory(dest)..createSync(recursive: true);
        await _copyDirectory(entity, child);
      } else if (entity is File) {
        await entity.copy(dest);
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

  Future<void> _copyLegacyFiles(Directory from, Directory to) async {
    await for (final entity in from.list(followLinks: false)) {
      if (entity.path == to.path ||
          entity.path.contains(
              '${Platform.pathSeparator}.versions${Platform.pathSeparator}')) {
        continue;
      }
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name.startsWith('.') && name != '.meta_mantle_dependencies.json') {
        continue;
      }
      final dest = '${to.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        final child = Directory(dest)..createSync(recursive: true);
        await _copyDirectory(entity, child);
      } else if (entity is File) {
        await entity.copy(dest);
      }
    }
  }

  Future<void> _writeFile(File file, String content) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${_nonce()}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
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
  HybridStaticGenerator(
      {required this.store,
      this.siteBaseUrl,
      this.siteId = 'default',
      DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
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
      CollectionRouteSource<T> source) async {
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
          'selected generation requires includeInInitialGeneration.');
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
        final page = await source.discover(cursor, source.pageSize);
        if (page.records.length > source.pageSize) {
          throw StateError('Source exceeded requested page size.');
        }
        discovered += page.records.length;
        if (discovered > source.maxRecords) {
          throw StateError(
              'Collection exceeded the configured maxRecords limit.');
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
            final path = _normalizePath(source.pathPattern
                .replaceAll(':key', Uri.encodeComponent(key)));
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
                }.toList()
                  ..sort(),
                generatedAt: _clock().toUtc(),
                sourceVersion:
                    document.sourceVersion ?? source.versionOf?.call(record),
                lastModified: document.lastModified,
                canonicalUrl: document.canonicalUrl ?? _defaultCanonical(path),
                indexable: document.indexable ?? true);
            pages.add(path);
          }));
        }
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
          completedAt: _clock().toUtc());
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }

  Future<HybridGenerationReport> generateFixedPages(
      Iterable<FixedRouteSource> routes) async {
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
      String version, Map<String, RouteDependency> dependencies) async {
    final priorSitemap = await store.readVersionSitemap(version);
    if (siteBaseUrl != null ||
        priorSitemap != null ||
        dependencies.values
            .any((dependency) => dependency.canonicalUrl != null)) {
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
      String path, RouteDependency previous) regenerate;

  /// Compares generated and published source versions. Return a negative value
  /// when [candidate] is older than [current]. If omitted, publication is
  /// fenced by the artifact base version only.
  final int Function(String candidate, String current)? compareSourceVersions;
  final DateTime Function() _clock;

  Future<List<String>> revalidatePath(String path) async {
    final normalized = _normalizePath(path);
    return _revalidateSelection((_, dependencies) async =>
        dependencies.containsKey(normalized) ? [normalized] : const []);
  }

  Future<List<String>> revalidateTag(String tag) async {
    if (tag.trim().isEmpty || tag.length > 200 || tag.contains('\u0000')) {
      throw const FormatException('Invalid dependency tag.');
    }
    return _revalidateSelection(
        (version, _) => store.loadVersionTagPaths(version, tag));
  }

  Future<List<String>> revalidateRoute(String routeId) async {
    if (routeId.trim().isEmpty || routeId.length > 200) {
      throw const FormatException('Invalid route ID.');
    }
    return _revalidateSelection(
        (version, _) => store.loadVersionRoutePaths(version, routeId));
  }

  Future<List<String>> revalidateAll() async {
    return _revalidateSelection(
        (_, dependencies) async => dependencies.keys.toList());
  }

  Future<List<String>> deleteRoute(String routeId) async {
    if (routeId.trim().isEmpty || routeId.length > 200) {
      throw const FormatException('Invalid route ID.');
    }
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final paths = deps.values
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
    ) select,
  ) async {
    final version = await store.beginVersion();
    try {
      final deps = await store.loadVersionDependencies(version);
      final paths = (await select(version, deps))
          .where(deps.containsKey)
          .toSet()
          .toList()
        ..sort();
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
      await store.publishVersion(version);
      return List.unmodifiable(paths);
    } catch (_) {
      await store.discardVersion(version);
      rethrow;
    }
  }
}

class StaleGeneratedDocumentException implements Exception {
  const StaleGeneratedDocumentException(
      this.path, this.candidateVersion, this.currentVersion);

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
        'siteBaseUrl must be an absolute HTTP(S) URL ending in /.');
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

/// Thrown when a draft was based on a publication that is no longer active.
class StaleArtifactVersionException implements Exception {
  const StaleArtifactVersionException(this.expected, this.current);
  final String expected;
  final String current;
  @override
  String toString() =>
      'Artifact draft is stale (based on "$expected", current is "$current").';
}
