import 'dart:convert';
import 'dart:io';

/// Records content hashes and output file paths for incremental static builds.
class IncrementalManifest {
  IncrementalManifest({
    Map<String, String>? routeFingerprints,
    Map<String, String>? ownedFiles,
  })  : routeFingerprints = routeFingerprints ?? {},
        ownedFiles = ownedFiles ?? {};

  /// Maps route path (e.g. `/about/`) to its content SHA/FNV hash.
  final Map<String, String> routeFingerprints;

  /// Maps route path to the relative output file path (e.g. `about/index.html`).
  final Map<String, String> ownedFiles;

  /// Loads an existing manifest file from disk if present.
  static Future<IncrementalManifest> load(File file) async {
    if (!await file.exists()) return IncrementalManifest();
    try {
      final text = await file.readAsString();
      final map = json.decode(text) as Map<String, dynamic>;
      final fingerprints = Map<String, String>.from(map['fingerprints'] ?? {});
      final files = Map<String, String>.from(map['ownedFiles'] ?? {});
      return IncrementalManifest(
        routeFingerprints: fingerprints,
        ownedFiles: files,
      );
    } catch (_) {
      return IncrementalManifest();
    }
  }

  /// Saves the manifest to disk.
  Future<void> save(File file) async {
    final payload = {
      'version': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'fingerprints': routeFingerprints,
      'ownedFiles': ownedFiles,
    };
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  /// Checks if [path] with [currentFingerprint] has changed compared to manifest.
  bool hasChanged(String path, String currentFingerprint) {
    return routeFingerprints[path] != currentFingerprint;
  }

  /// Records an updated route fingerprint and file path.
  void record(String path, String fingerprint, String relativeFilePath) {
    routeFingerprints[path] = fingerprint;
    ownedFiles[path] = relativeFilePath;
  }

  /// Identifies routes that were previously generated but are no longer in [activeRoutes].
  Set<String> findObsoleteRoutes(Set<String> activeRoutes) {
    return ownedFiles.keys.toSet().difference(activeRoutes);
  }

  /// Computes a fast deterministic hash of content strings.
  static String computeFingerprint(String content) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < content.length; i++) {
      hash ^= content.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
