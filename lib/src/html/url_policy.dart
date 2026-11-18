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
  static final RegExp _rawWhitespace = RegExp(r'\s');
  static final RegExp _schemeFormat = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$');

  /// Validates RFC 3986 scheme syntax (`^[a-zA-Z][a-zA-Z0-9+.-]*$`).
  static bool isValidSchemeName(String scheme) =>
      _schemeFormat.hasMatch(scheme);

  /// Returns `true` when [url] is considered safe by this policy.
  ///
  /// - Validates original input before any normalization or trimming.
  /// - Raw control characters (C0: 0x00–0x1F, C1: 0x7F–0x9F) and raw whitespace
  ///   (including leading/trailing whitespace such as `\n`, `\r`, `\t`) are strictly rejected.
  /// - Backslashes (`\`) are strictly rejected.
  /// - Empty string is allowed.
  /// - Fragment-only (`#…`) and query-only (`?…`) URLs are allowed.
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

    // 1. Reject original C0 (0x00-0x1F) and C1 (0x7F-0x9F) control characters immediately
    if (url.contains(_controlChars)) {
      return false;
    }

    // 2. Reject raw whitespace (including leading/trailing whitespace such as \n, \r, \t)
    if (url.contains(_rawWhitespace)) {
      return false;
    }

    // 3. Reject backslashes immediately
    if (url.contains(r'\')) {
      return false;
    }

    // 4. Protocol-relative check on raw URL
    final isProtocolRelative = url.startsWith('//');
    if (isProtocolRelative && !allowProtocolRelative) {
      return false;
    }

    // 5. Iteratively decode percent-encoding to detect obfuscated schemes or bypasses
    var decoded = url;
    for (var i = 0; i < 3; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }

    // 6. If decoded URL introduces control characters, whitespace, or backslashes, reject
    if (decoded.contains(_controlChars) ||
        decoded.contains(_rawWhitespace) ||
        decoded.contains(r'\')) {
      return false;
    }

    // 7. Re-check protocol-relative after decoding
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

    // 8. If starts with #, ?, or safe single-slash root-relative, it's relative
    if (decoded.startsWith('#') || decoded.startsWith('?')) {
      return true;
    }
    if (decoded.startsWith('/')) {
      return !decoded.startsWith('//');
    }

    // 9. Extract potential scheme by checking text before first '/', '?', or '#'
    final firstColon = decoded.indexOf(':');
    final firstSlash = decoded.indexOf('/');
    final firstQuestion = decoded.indexOf('?');
    final firstHash = decoded.indexOf('#');

    final activeAllowed = (allowedSchemes ?? defaultAllowedSchemes)
        .map((s) => s.toLowerCase())
        .toSet();

    if (firstColon != -1) {
      final isBeforeSlash = firstSlash == -1 || firstColon < firstSlash;
      final isBeforeQuestion =
          firstQuestion == -1 || firstColon < firstQuestion;
      final isBeforeHash = firstHash == -1 || firstColon < firstHash;

      if (isBeforeSlash && isBeforeQuestion && isBeforeHash) {
        final scheme = decoded.substring(0, firstColon).toLowerCase();
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
