/// Configuration entry for a server redirect rule.
class RedirectRule {
  const RedirectRule({
    required this.fromPath,
    required this.toPath,
    this.statusCode = 301,
  }) : assert(
         statusCode == 301 ||
             statusCode == 302 ||
             statusCode == 307 ||
             statusCode == 308,
         'Redirect status code must be 301, 302, 307, or 308.',
       );

  final String fromPath;
  final String toPath;
  final int statusCode;
}

/// Result of evaluating a redirect through [RedirectManager].
class RedirectResolution {
  const RedirectResolution({
    required this.targetPath,
    required this.statusCode,
    required this.hopCount,
  });

  final String targetPath;
  final int statusCode;
  final int hopCount;
}

/// Manages route redirects with loop detection, chain collapsing, and open redirect protection.
class RedirectManager {
  RedirectManager({
    List<RedirectRule> rules = const [],
    this.maxHops = 5,
    this.allowedHosts = const {},
  }) {
    for (final rule in rules) {
      add(rule);
    }
  }

  final int maxHops;
  final Set<String> allowedHosts;
  final Map<String, RedirectRule> _rules = {};

  /// Registers a redirect rule.
  void add(RedirectRule rule) {
    _rules[_normalize(rule.fromPath)] = rule;
  }

  /// Resolves any redirects for [path].
  ///
  /// Returns `null` if no redirect exists for [path].
  /// Collapses redirect chains (e.g. A -> B -> C becomes A -> C) and throws
  /// [StateError] if a redirect cycle is detected or [maxHops] is exceeded.
  RedirectResolution? resolve(String path) {
    var current = _normalize(path);
    final visited = <String>{current};
    var hops = 0;
    int? finalStatus;

    while (_rules.containsKey(current)) {
      hops++;
      if (hops > maxHops) {
        throw StateError(
          'Redirect chain exceeded maximum hops ($maxHops): $path',
        );
      }

      final rule = _rules[current]!;
      finalStatus ??= rule.statusCode;

      final next = _normalize(rule.toPath);
      _validateDestination(rule.toPath);

      if (!visited.add(next)) {
        throw StateError(
          'Redirect loop detected for path: $path (cycle at $next)',
        );
      }

      current = next;
    }

    if (hops == 0) return null;

    return RedirectResolution(
      targetPath: current,
      statusCode: finalStatus ?? 301,
      hopCount: hops,
    );
  }

  void _validateDestination(String target) {
    if (target.startsWith('/')) return; // Safe relative redirect

    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) {
      throw FormatException('Invalid redirect target: $target');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Disallowed redirect scheme: ${uri.scheme}');
    }

    if (allowedHosts.isNotEmpty &&
        !allowedHosts.contains(uri.host.toLowerCase())) {
      throw FormatException(
        'Redirect to unlisted external host is disallowed: ${uri.host}',
      );
    }
  }

  static String _normalize(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final trimmed = path.trim();
    if (!trimmed.startsWith('/')) return '/$trimmed';
    return trimmed;
  }
}
