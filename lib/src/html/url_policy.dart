/// Unified URL validation policy for MetaMantle HTML serialization.
///
/// All URL allowlist/denylist logic lives here. [ElementNode.assertSafeUrl],
/// [HeadTag.toHtml], [HtmlDocument.render], and [HtmlSanitizer.isValidUrl]
/// delegate to this class so they share unified security behavior.
class UrlPolicy {
  UrlPolicy._();

  /// Default schemes explicitly allowed by policy (allowlist).
  static const Set<String> defaultAllowedSchemes = {
    'http',
    'https',
    'mailto',
    'tel',
  };

  /// Inherently dangerous schemes that can NEVER be permitted by policy.
  static const Set<String> prohibitedSchemes = {
    'javascript',
    'vbscript',
    'data',
    'blob',
    'file',
  };

  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F]');
  static final RegExp _schemeFormat = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$');

  /// Validates RFC 3986 scheme syntax (`^[a-zA-Z][a-zA-Z0-9+.-]*$`).
  static bool isValidSchemeName(String scheme) =>
      _schemeFormat.hasMatch(scheme);

  /// Returns `true` when [url] is considered safe by this policy.
  ///
  /// - Raw control characters (0x00–0x1F, 0x7F-0x9F) and raw unencoded whitespace are strictly rejected.
  /// - Backslashes (`\`) are strictly rejected.
  /// - Empty string and fragment-only (`#…`) URLs are allowed.
  /// - Protocol-relative (`//`) is rejected unless [allowProtocolRelative] is `true`.
  /// - Encoded obfuscated schemes (`%6a%61%76%61...`) are unmasked and rejected.
  /// - Prohibited schemes ([prohibitedSchemes]) are ALWAYS rejected regardless of configuration.
  /// - Schemed URLs: only [allowedSchemes] (defaults to [defaultAllowedSchemes]) pass.
  static bool isSafe(
    String url, {
    Set<String>? allowedSchemes,
    bool allowProtocolRelative = false,
  }) {
    if (url.isEmpty) return true;

    final trimmed = url.trim();
    if (trimmed.isEmpty) return true;

    // Reject raw forbidden control characters (C0: 0x00-0x1F, C1: 0x7F-0x9F)
    if (trimmed.contains(_controlChars)) {
      return false;
    }

    // Reject unencoded whitespace inside URL
    if (trimmed.contains(RegExp(r'\s'))) {
      return false;
    }

    // Reject backslash-based bypasses immediately
    if (trimmed.contains(r'\')) {
      return false;
    }

    final isProtocolRelative = trimmed.startsWith('//');
    if (isProtocolRelative && !allowProtocolRelative) {
      return false;
    }

    // Iteratively decode percent-encoding to detect obfuscated schemes
    var decoded = trimmed;
    for (var i = 0; i < 2; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }

    // If decoded URL introduces control characters or backslashes, reject
    if (decoded.contains(_controlChars) || decoded.contains(r'\')) {
      return false;
    }

    // Re-check protocol-relative after decoding
    final isDecodedProtocolRelative = decoded.startsWith('//');
    if (isDecodedProtocolRelative && !allowProtocolRelative) {
      return false;
    }

    // If allowed protocol-relative URL, verify it has a valid host structure
    if (isDecodedProtocolRelative && allowProtocolRelative) {
      final afterSlashes = decoded.substring(2);
      final slashIndex = afterSlashes.indexOf('/');
      final hostPart = slashIndex == -1
          ? afterSlashes
          : afterSlashes.substring(0, slashIndex);
      if (hostPart.isEmpty || hostPart.contains('@')) {
        return false;
      }
      return true;
    }

    // If starts with #, ?, or safe single-slash root-relative, it's relative
    if (decoded.startsWith('#') || decoded.startsWith('?')) {
      return true;
    }
    if (decoded.startsWith('/')) {
      return !decoded.startsWith('//');
    }

    // Extract potential scheme by checking text before first '/', '?', or '#'
    final stripped = decoded.replaceAll(RegExp(r'\s+'), '');
    final firstColon = stripped.indexOf(':');
    final firstSlash = stripped.indexOf('/');
    final firstQuestion = stripped.indexOf('?');
    final firstHash = stripped.indexOf('#');

    final activeAllowed = (allowedSchemes ?? defaultAllowedSchemes)
        .map((s) => s.toLowerCase())
        .toSet();

    if (firstColon != -1) {
      final isBeforeSlash = firstSlash == -1 || firstColon < firstSlash;
      final isBeforeQuestion =
          firstQuestion == -1 || firstColon < firstQuestion;
      final isBeforeHash = firstHash == -1 || firstColon < firstHash;

      if (isBeforeSlash && isBeforeQuestion && isBeforeHash) {
        final scheme = stripped.substring(0, firstColon).toLowerCase();
        // Dangerous schemes are ALWAYS rejected, even if someone attempted to allowlist them
        if (prohibitedSchemes.contains(scheme)) {
          return false;
        }
        return activeAllowed.contains(scheme);
      }
    }

    // No scheme found before path separators -> relative URL path
    return true;
  }

  /// Throws [ArgumentError] if [url] is not safe according to this policy.
  static void assertSafe(
    String url,
    String attributeName, {
    Set<String>? allowedSchemes,
    bool allowProtocolRelative = false,
  }) {
    if (!isSafe(
      url,
      allowedSchemes: allowedSchemes,
      allowProtocolRelative: allowProtocolRelative,
    )) {
      throw ArgumentError.value(
        url,
        attributeName,
        'Potentially unsafe URL rejected by UrlPolicy ($attributeName)',
      );
    }
  }
}
