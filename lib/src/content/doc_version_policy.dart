import '../models/metadata.dart';

/// Directive decision for versioned documentation routes.
class DocVersionDecision {
  const DocVersionDecision({
    required this.canonicalUrl,
    required this.robots,
    required this.isLatest,
    this.redirectTarget,
  });

  final String canonicalUrl;
  final String robots;
  final bool isLatest;
  final String? redirectTarget;
}

/// SEO policy governing versioned documentation portals (`/docs/v1/`, `/docs/latest/`).
class DocVersionPolicy {
  const DocVersionPolicy({
    required this.baseDocsUrl,
    this.latestVersion = 'latest',
    this.supportedVersions = const ['latest', 'v1', 'v2', 'next'],
    this.canonicalizeToLatest = true,
    this.noindexOlderVersions = true,
  });

  final String baseDocsUrl;
  final String latestVersion;
  final List<String> supportedVersions;
  final bool canonicalizeToLatest;
  final bool noindexOlderVersions;

  /// Evaluates an incoming documentation path (e.g. `/docs/v1/getting-started/`).
  DocVersionDecision evaluate(String path) {
    final cleanBase = baseDocsUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/+|/+$'), '');

    var relativePath = cleanPath;
    final baseUri = Uri.tryParse(cleanBase);
    final basePath = (baseUri?.path ?? '').replaceAll(RegExp(r'^/+|/+$'), '');
    if (basePath.isNotEmpty && relativePath.startsWith(basePath)) {
      relativePath = relativePath
          .substring(basePath.length)
          .replaceAll(RegExp(r'^/+'), '');
    }
    final segments =
        relativePath.isEmpty ? <String>[] : relativePath.split('/');

    // Identify which version segment is present
    String? matchedVersion;
    int versionIndex = -1;
    for (var i = 0; i < segments.length; i++) {
      if (supportedVersions.contains(segments[i])) {
        matchedVersion = segments[i];
        versionIndex = i;
        break;
      }
    }

    final currentUrl =
        relativePath.isEmpty ? '$cleanBase/' : '$cleanBase/$relativePath/';

    if (matchedVersion == null) {
      // Unversioned doc route -> assume latest
      return DocVersionDecision(
        canonicalUrl: currentUrl,
        robots: RobotsDirective.indexFollow,
        isLatest: true,
      );
    }

    final isLatest = matchedVersion == latestVersion;
    final pathWithoutVersion = [
      ...segments.sublist(0, versionIndex),
      ...segments.sublist(versionIndex + 1),
    ].join('/');

    final latestPath = pathWithoutVersion.isEmpty
        ? '$cleanBase/$latestVersion/'
        : '$cleanBase/$latestVersion/$pathWithoutVersion/';

    final canonicalUrl =
        (canonicalizeToLatest && !isLatest) ? latestPath : currentUrl;

    final robots = (!isLatest && noindexOlderVersions)
        ? RobotsDirective.noindexFollow
        : RobotsDirective.indexFollow;

    return DocVersionDecision(
      canonicalUrl: canonicalUrl,
      robots: robots,
      isLatest: isLatest,
    );
  }
}
