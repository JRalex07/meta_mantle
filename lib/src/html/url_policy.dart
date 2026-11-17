/// Unified URL validation policy for MetaMantle HTML serialization.
///
/// All URL allowlist/denylist logic lives here. Both [ElementNode.assertSafeUrl]
/// and [HtmlSanitizer.isValidUrl] delegate to this class so they share
/// identical behavior.
class UrlPolicy {
  UrlPolicy._();

  /// Schemes explicitly allowed by policy (allowlist — unknown schemes REJECTED).
  static const Set<String> _allowedSchemes = {'http', 'https', 'mailto', 'tel'};

  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  /// Returns `true` when [url] is considered safe by this policy.
  ///
  /// - Control chars (0x00–0x1F, 0x7F) are stripped before evaluation.
  /// - Empty string and fragment-only (`#…`) URLs are allowed.
  /// - Protocol-relative (`//`), backslash bypasses (`\`, `/\`, `\/`, `\\`) → rejected.
  /// - Encoded and whitespace-obfuscated schemes (e.g. `%6a%61%76%61...`, `java\tscript:`) → rejected.
  /// - Root-relative (`/path`) → allowed.
  /// - Relative paths (no scheme) → allowed.
  /// - Schemed URLs: only [_allowedSchemes] pass. All other schemes (javascript,
  ///   vbscript, data, blob, file, unknown) are rejected.
  static bool isSafe(String url) {
    if (url.isEmpty) return true;

    // Strip control characters (0x00-0x1F, 0x7F) and trim
    final cleaned = url.replaceAll(_controlChars, '').trim();
    if (cleaned.isEmpty) return true;

    // Reject protocol-relative and backslash-based bypasses immediately
    if (cleaned.startsWith(r'\') ||
        cleaned.startsWith('//') ||
        cleaned.startsWith(r'/\') ||
        cleaned.startsWith(r'\\') ||
        cleaned.startsWith(r'/\\') ||
        cleaned.startsWith(r'\/')) {
      return false;
    }

    // Iteratively decode percent-encoding to detect obfuscated schemes
    var decoded = cleaned;
    for (var i = 0; i < 2; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }

    // Strip control characters again post-decode
    decoded = decoded.replaceAll(_controlChars, '').trim();

    // Re-check protocol-relative and backslash bypasses after decoding
    if (decoded.startsWith(r'\') ||
        decoded.startsWith('//') ||
        decoded.startsWith(r'/\') ||
        decoded.startsWith(r'\\') ||
        decoded.startsWith(r'/\\') ||
        decoded.startsWith(r'\/')) {
      return false;
    }

    // If starts with #, ?, or safe single-slash root-relative, it's relative
    if (decoded.startsWith('#') || decoded.startsWith('?')) {
      return true;
    }
    if (decoded.startsWith('/')) {
      // Must not be followed by another slash or backslash
      return !decoded.startsWith('//') &&
          !decoded.startsWith(r'/\') &&
          !decoded.startsWith(r'/\\');
    }

    // Extract potential scheme by checking text before first '/', '?', or '#'
    // Ignore internal whitespace in candidate scheme to counter `java\nscript:`
    final stripped = decoded.replaceAll(RegExp(r'\s+'), '');
    final firstColon = stripped.indexOf(':');
    final firstSlash = stripped.indexOf('/');
    final firstQuestion = stripped.indexOf('?');
    final firstHash = stripped.indexOf('#');

    // A scheme must precede any path separator '/', query '?', or fragment '#'
    if (firstColon != -1) {
      final isBeforeSlash = firstSlash == -1 || firstColon < firstSlash;
      final isBeforeQuestion =
          firstQuestion == -1 || firstColon < firstQuestion;
      final isBeforeHash = firstHash == -1 || firstColon < firstHash;

      if (isBeforeSlash && isBeforeQuestion && isBeforeHash) {
        final scheme = stripped.substring(0, firstColon).toLowerCase();
        // Allowlist check: ONLY explicitly permitted schemes pass!
        return _allowedSchemes.contains(scheme);
      }
    }

    // No scheme found before path separators -> relative URL path
    return true;
  }

  /// Like [isSafe], but throws an [ArgumentError] on violations.
  ///
  /// [context] is used as the parameter name in the error message.
  static void assertSafe(String url, String context) {
    if (!isSafe(url)) {
      final cleaned = url.replaceAll(_controlChars, '').trim();
      final reason = _reason(cleaned, url);
      throw ArgumentError.value(url, context, reason);
    }
  }

  static String _reason(String cleaned, String original) {
    if (cleaned.startsWith(r'\') ||
        cleaned.startsWith('//') ||
        cleaned.startsWith(r'/\') ||
        cleaned.startsWith(r'\\') ||
        cleaned.startsWith(r'/\\') ||
        cleaned.startsWith(r'\/')) {
      return 'Protocol-relative or backslash URLs are prohibited for security';
    }

    final stripped = cleaned.replaceAll(RegExp(r'\s+'), '');
    final colonIndex = stripped.indexOf(':');
    final slashIndex = stripped.indexOf('/');
    if (colonIndex != -1 && (slashIndex == -1 || colonIndex < slashIndex)) {
      final scheme = stripped.substring(0, colonIndex).toLowerCase();
      return 'URL scheme "$scheme:" is not in the allowed list '
          '(allowed: ${_allowedSchemes.join(', ')})';
    }
    return 'URL is not safe: $original';
  }
}
