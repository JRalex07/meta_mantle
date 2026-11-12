import 'dart:convert';

/// Standard social media card dimensions.
class SocialCardDimensions {
  const SocialCardDimensions({
    required this.width,
    required this.height,
    this.name = 'custom',
  });

  final int width;
  final int height;
  final String name;

  /// Standard Open Graph image (Facebook, LinkedIn, Discord): 1200 x 630 px.
  static const SocialCardDimensions openGraph = SocialCardDimensions(
    width: 1200,
    height: 630,
    name: 'open_graph',
  );

  /// Twitter / X Summary Large Image: 1200 x 628 px.
  static const SocialCardDimensions twitterLarge = SocialCardDimensions(
    width: 1200,
    height: 628,
    name: 'twitter_large',
  );

  /// Square card (Instagram / Twitter small): 600 x 600 px.
  static const SocialCardDimensions square = SocialCardDimensions(
    width: 600,
    height: 600,
    name: 'square',
  );
}

/// Visual branding theme for generated social preview cards.
class SocialCardTheme {
  const SocialCardTheme({
    this.backgroundColor = '#0f172a',
    this.backgroundGradientEnd = '#1e293b',
    this.accentColor = '#38bdf8',
    this.titleColor = '#f8fafc',
    this.subtitleColor = '#94a3b8',
    this.badgeBackgroundColor = 'rgba(56, 189, 248, 0.15)',
    this.badgeTextColor = '#38bdf8',
    this.fontFamily = 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  });

  final String backgroundColor;
  final String backgroundGradientEnd;
  final String accentColor;
  final String titleColor;
  final String subtitleColor;
  final String badgeBackgroundColor;
  final String badgeTextColor;
  final String fontFamily;
}

/// Content payload used to synthesize a dynamic social preview card.
class SocialCardData {
  const SocialCardData({
    required this.title,
    this.subtitle,
    this.siteName = 'MetaMantle',
    this.categoryBadge,
    this.authorName,
    this.authorAvatarUrl,
    this.logoUrl,
    this.productImageUrl,
    this.priceTag,
  });

  final String title;
  final String? subtitle;
  final String siteName;
  final String? categoryBadge;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? logoUrl;
  final String? productImageUrl;
  final String? priceTag;
}

/// Dynamic SVG-based social image generator with safe XML escaping and in-memory caching.
class SocialImageGenerator {
  SocialImageGenerator({this.maxCachedImages = 500});

  final int maxCachedImages;
  final Map<String, String> _cache = {};

  /// Generates a resolution-independent SVG social image card.
  String generateSvg(
    SocialCardData data, {
    SocialCardDimensions dimensions = SocialCardDimensions.openGraph,
    SocialCardTheme theme = const SocialCardTheme(),
  }) {
    final cacheKey =
        '${dimensions.name}:${data.title}:${data.subtitle}:${data.categoryBadge}:${data.priceTag}';
    final existing = _cache[cacheKey];
    if (existing != null) {
      // Re-insert for LRU recency
      _cache.remove(cacheKey);
      _cache[cacheKey] = existing;
      return existing;
    }

    final svg = _renderSvg(data, dimensions, theme);

    if (_cache.length >= maxCachedImages) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = svg;
    return svg;
  }

  /// Converts an SVG string into a data URI (`data:image/svg+xml;utf8,...`)
  /// for direct use in `<meta property="og:image">`.
  String toDataUri(String svg) {
    final encoded = Uri.encodeComponent(svg)
        .replaceAll('%20', ' ')
        .replaceAll('%3D', '=')
        .replaceAll('%3A', ':')
        .replaceAll('%2F', '/');
    return 'data:image/svg+xml;utf8,$encoded';
  }

  /// Clears in-memory card cache.
  void clearCache() => _cache.clear();

  int get cachedCount => _cache.length;

  String _renderSvg(
    SocialCardData data,
    SocialCardDimensions dim,
    SocialCardTheme theme,
  ) {
    final buf = StringBuffer();
    final w = dim.width;
    final h = dim.height;

    buf.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">',
    );
    buf.writeln('  <defs>');
    buf.writeln(
      '    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">',
    );
    buf.writeln(
      '      <stop offset="0%" stop-color="${_escape(theme.backgroundColor)}" />',
    );
    buf.writeln(
      '      <stop offset="100%" stop-color="${_escape(theme.backgroundGradientEnd)}" />',
    );
    buf.writeln('    </linearGradient>');
    buf.writeln(
      '    <filter id="cardShadow" x="-10%" y="-10%" width="120%" height="120%">',
    );
    buf.writeln(
      '      <feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#000" flood-opacity="0.35" />',
    );
    buf.writeln('    </filter>');
    buf.writeln('  </defs>');

    // Background
    buf.writeln('  <rect width="$w" height="$h" fill="url(#bgGrad)" />');

    // Accent header bar
    buf.writeln(
      '  <rect x="0" y="0" width="$w" height="6" fill="${_escape(theme.accentColor)}" />',
    );

    // Branding / Site Name Header
    buf.writeln('  <g id="header" transform="translate(80, 80)">');
    if (data.categoryBadge != null) {
      final badgeText = _escape(data.categoryBadge!.toUpperCase());
      final badgeWidth = (badgeText.length * 11) + 32;
      buf.writeln(
        '    <rect x="0" y="0" width="$badgeWidth" height="34" rx="17" fill="${_escape(theme.badgeBackgroundColor)}" />',
      );
      buf.writeln(
        '    <text x="${badgeWidth / 2}" y="22" font-family="${_escape(theme.fontFamily)}" font-size="13" font-weight="700" fill="${_escape(theme.badgeTextColor)}" text-anchor="middle" letter-spacing="1">$badgeText</text>',
      );
      buf.writeln(
        '    <text x="${badgeWidth + 20}" y="24" font-family="${_escape(theme.fontFamily)}" font-size="20" font-weight="600" fill="${_escape(theme.subtitleColor)}">${_escape(data.siteName)}</text>',
      );
    } else {
      buf.writeln(
        '    <text x="0" y="24" font-family="${_escape(theme.fontFamily)}" font-size="22" font-weight="700" fill="${_escape(theme.accentColor)}" letter-spacing="0.5">${_escape(data.siteName)}</text>',
      );
    }
    buf.writeln('  </g>');

    // Main Title with Multi-line Wrapping
    final titleLines = _wrapText(data.title, maxCharsPerLine: 34);
    buf.writeln('  <g id="title" transform="translate(80, 200)">');
    for (var i = 0; i < titleLines.length && i < 3; i++) {
      final lineY = i * 62;
      buf.writeln(
        '    <text x="0" y="$lineY" font-family="${_escape(theme.fontFamily)}" font-size="52" font-weight="800" fill="${_escape(theme.titleColor)}" letter-spacing="-0.02em">${_escape(titleLines[i])}</text>',
      );
    }
    buf.writeln('  </g>');

    // Subtitle
    if (data.subtitle != null) {
      final subY = 220 + (titleLines.length.clamp(1, 3) * 62);
      final subLines = _wrapText(data.subtitle!, maxCharsPerLine: 50);
      buf.writeln('  <g id="subtitle" transform="translate(80, $subY)">');
      for (var i = 0; i < subLines.length && i < 2; i++) {
        final lineY = i * 32;
        buf.writeln(
          '    <text x="0" y="$lineY" font-family="${_escape(theme.fontFamily)}" font-size="22" font-weight="400" fill="${_escape(theme.subtitleColor)}">${_escape(subLines[i])}</text>',
        );
      }
      buf.writeln('  </g>');
    }

    // Optional E-Commerce Product Image or Price Tag
    if (data.productImageUrl != null || data.priceTag != null) {
      buf.writeln(
        '  <g id="productInfo" transform="translate(${w - 380}, 160)">',
      );
      buf.writeln(
        '    <rect width="300" height="300" rx="24" fill="#1e293b" filter="url(#cardShadow)" />',
      );
      if (data.productImageUrl != null) {
        buf.writeln(
          '    <image href="${_escape(data.productImageUrl!)}" x="20" y="20" width="260" height="200" preserveAspectRatio="xMidYMid meet" />',
        );
      }
      if (data.priceTag != null) {
        buf.writeln(
          '    <rect x="20" y="235" width="260" height="45" rx="12" fill="${_escape(theme.accentColor)}" />',
        );
        buf.writeln(
          '    <text x="150" y="265" font-family="${_escape(theme.fontFamily)}" font-size="22" font-weight="800" fill="#0f172a" text-anchor="middle">${_escape(data.priceTag!)}</text>',
        );
      }
      buf.writeln('  </g>');
    }

    // Footer Author / Call to Action
    if (data.authorName != null) {
      buf.writeln('  <g id="footer" transform="translate(80, ${h - 70})">');
      buf.writeln(
        '    <circle cx="16" cy="0" r="16" fill="${_escape(theme.accentColor)}" />',
      );
      buf.writeln(
        '    <text x="16" y="6" font-family="${_escape(theme.fontFamily)}" font-size="14" font-weight="700" fill="#0f172a" text-anchor="middle">${_escape(data.authorName!.substring(0, 1).toUpperCase())}</text>',
      );
      buf.writeln(
        '    <text x="44" y="6" font-family="${_escape(theme.fontFamily)}" font-size="18" font-weight="500" fill="${_escape(theme.subtitleColor)}">Written by ${_escape(data.authorName!)}</text>',
      );
      buf.writeln('  </g>');
    }

    buf.writeln('</svg>');
    return buf.toString();
  }

  static List<String> _wrapText(String text, {required int maxCharsPerLine}) {
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + word.length + 1 <= maxCharsPerLine) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines;
  }

  static String _escape(String input) {
    return const HtmlEscape(HtmlEscapeMode.attribute).convert(input);
  }
}
