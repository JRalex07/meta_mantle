import '../models/metadata.dart';
import 'head_tag.dart';

/// Resolves global defaults and page metadata into deterministic head tags.
class MetadataRenderer {
  const MetadataRenderer();

  List<HeadTag> render(
    WebMetadata metadata, {
    MetaMantleConfig config = const MetaMantleConfig(),
    String? currentUrl,
  }) {
    final title = _resolveTitle(metadata, config);
    final description = metadata.description ?? config.defaultDescription;
    final keywords = metadata.keywords ?? config.defaultKeywords;
    final author = metadata.author ?? config.defaultAuthor;
    final publisher = metadata.publisher ?? config.defaultPublisher;
    final applicationName =
        metadata.applicationName ?? config.defaultApplicationName;
    final referrerPolicy = metadata.referrerPolicy;
    final colorScheme = metadata.colorScheme ?? config.colorScheme;

    final rawCanonical = metadata.canonical ??
        (config.includeCurrentUrlAsCanonical ? currentUrl : null);
    final resolvedCanonical = _resolveUrl(rawCanonical, config.baseUrl);
    final canonical = _applyTrailingSlash(
      resolvedCanonical,
      metadata.trailingSlash ?? config.trailingSlash,
    );

    if (canonical != null) {
      final canonicalUri = Uri.parse(canonical);
      if (!canonicalUri.hasScheme ||
          (canonicalUri.scheme != 'http' && canonicalUri.scheme != 'https') ||
          !canonicalUri.hasAuthority ||
          canonicalUri.host.isEmpty ||
          canonicalUri.userInfo.isNotEmpty ||
          canonicalUri.hasQuery ||
          canonicalUri.hasFragment) {
        throw FormatException(
          'Canonical URLs must be absolute HTTP(S) URLs without credentials, query or fragment: $canonical',
        );
      }
    }

    final robots = metadata.robots ?? config.defaultRobots;
    final image = metadata.openGraph?.image ?? config.defaultImage;
    final ogTitle = metadata.openGraph?.title ?? title;
    final ogDescription = metadata.openGraph?.description ?? description;
    final ogUrl = _resolveUrl(
      metadata.openGraph?.url ?? canonical,
      config.baseUrl,
    );
    final ogSiteName = metadata.openGraph?.siteName ?? config.siteName;
    final ogType = metadata.openGraph?.type ?? OpenGraphType.website;
    final twitter = metadata.twitter;
    final resolvedLanguage = metadata.language ?? config.language;
    final tags = <HeadTag>[];

    void addMeta(String key, String name, String content) {
      tags.add(HeadTag(
        key: key,
        tagName: 'meta',
        attributes: {'name': name, 'content': content},
      ));
    }

    void addProperty(String key, String property, String content) {
      tags.add(HeadTag(
        key: key,
        tagName: 'meta',
        attributes: {'property': property, 'content': content},
      ));
    }

    if (title != null && title.isNotEmpty) {
      tags.add(HeadTag(key: 'title', tagName: 'title', textContent: title));
    }
    if (description != null && description.isNotEmpty) {
      addMeta('description', 'description', description);
    }
    if (keywords != null && keywords.isNotEmpty) {
      addMeta('keywords', 'keywords', keywords);
    }
    if (author != null && author.isNotEmpty) {
      addMeta('author', 'author', author);
    }
    if (publisher != null && publisher.isNotEmpty) {
      addMeta('publisher', 'publisher', publisher);
    }
    if (applicationName != null && applicationName.isNotEmpty) {
      addMeta('application-name', 'application-name', applicationName);
    }
    if (referrerPolicy != null && referrerPolicy.isNotEmpty) {
      addMeta('referrer', 'referrer', referrerPolicy);
    }
    if (colorScheme != null && colorScheme.isNotEmpty) {
      addMeta('color-scheme', 'color-scheme', colorScheme);
    }
    if (robots != null && robots.isNotEmpty) {
      addMeta('robots', 'robots', robots);
    }
    if (canonical != null) {
      tags.add(HeadTag(
        key: 'canonical',
        tagName: 'link',
        attributes: {'rel': 'canonical', 'href': canonical},
      ));
    }
    final themeColor = metadata.themeColor ?? config.themeColor;
    if (themeColor != null && themeColor.isNotEmpty) {
      addMeta('theme-color', 'theme-color', themeColor);
    }
    if (resolvedLanguage != null && resolvedLanguage.isNotEmpty) {
      tags.add(HeadTag(
        key: 'html-language',
        tagName: 'html',
        attributes: {'lang': resolvedLanguage},
      ));
    }

    // Search Engine Verifications
    if (metadata.googleSiteVerification != null &&
        metadata.googleSiteVerification!.isNotEmpty) {
      addMeta(
        'google-site-verification',
        'google-site-verification',
        metadata.googleSiteVerification!,
      );
    }
    if (metadata.bingSiteVerification != null &&
        metadata.bingSiteVerification!.isNotEmpty) {
      addMeta(
        'msvalidate.01',
        'msvalidate.01',
        metadata.bingSiteVerification!,
      );
    }
    if (metadata.yandexVerification != null &&
        metadata.yandexVerification!.isNotEmpty) {
      addMeta(
        'yandex-verification',
        'yandex-verification',
        metadata.yandexVerification!,
      );
    }
    if (metadata.baiduVerification != null &&
        metadata.baiduVerification!.isNotEmpty) {
      addMeta(
        'baidu-site-verification',
        'baidu-site-verification',
        metadata.baiduVerification!,
      );
    }

    // Open Graph
    final og = metadata.openGraph;
    if (ogTitle != null) addProperty('og:title', 'og:title', ogTitle);
    if (ogDescription != null) {
      addProperty('og:description', 'og:description', ogDescription);
    }
    if (ogUrl != null) addProperty('og:url', 'og:url', ogUrl);
    if (image != null) {
      addProperty('og:image', 'og:image', _resolveUrl(image, config.baseUrl)!);
    }
    addProperty('og:type', 'og:type', ogType);
    if (ogSiteName != null) {
      addProperty('og:site_name', 'og:site_name', ogSiteName);
    }
    if (og?.locale case final locale?) {
      addProperty('og:locale', 'og:locale', locale);
    }
    if (og?.imageAlt case final alt?) {
      addProperty('og:image:alt', 'og:image:alt', alt);
    }
    if (og?.imageWidth case final width?) {
      addProperty('og:image:width', 'og:image:width', width.toString());
    }
    if (og?.imageHeight case final height?) {
      addProperty('og:image:height', 'og:image:height', height.toString());
    }
    if (og?.imageType case final imageType?) {
      addProperty('og:image:type', 'og:image:type', imageType);
    }
    if (og?.determiner case final determiner?) {
      addProperty('og:determiner', 'og:determiner', determiner);
    }
    if (og?.video case final video?) {
      addProperty('og:video', 'og:video', _resolveUrl(video, config.baseUrl)!);
    }
    if (og?.audio case final audio?) {
      addProperty('og:audio', 'og:audio', _resolveUrl(audio, config.baseUrl)!);
    }
    if (og != null) {
      for (var i = 0; i < og.alternateLocales.length; i++) {
        addProperty(
          'og:locale:alternate-$i',
          'og:locale:alternate',
          og.alternateLocales[i],
        );
      }
    }

    // Twitter / X Cards
    if (twitter != null ||
        title != null ||
        description != null ||
        image != null) {
      final card = twitter?.card ?? TwitterCardType.summaryLargeImage;
      addMeta('twitter:card', 'twitter:card', card);
      final resolvedTwitterTitle = twitter?.title ?? ogTitle;
      final resolvedTwitterDescription = twitter?.description ?? ogDescription;
      final resolvedTwitterImage = twitter?.image ?? image;
      if (resolvedTwitterTitle != null) {
        addMeta('twitter:title', 'twitter:title', resolvedTwitterTitle);
      }
      if (resolvedTwitterDescription != null) {
        addMeta(
          'twitter:description',
          'twitter:description',
          resolvedTwitterDescription,
        );
      }
      if (resolvedTwitterImage != null) {
        addMeta(
          'twitter:image',
          'twitter:image',
          _resolveUrl(resolvedTwitterImage, config.baseUrl)!,
        );
      }
      if (twitter?.imageAlt case final alt?) {
        addMeta('twitter:image:alt', 'twitter:image:alt', alt);
      }
      if (twitter?.site case final site?) {
        addMeta('twitter:site', 'twitter:site', site);
      }
      if (twitter?.creator case final creator?) {
        addMeta('twitter:creator', 'twitter:creator', creator);
      }
    }

    // JSON-LD Scripts
    for (var i = 0; i < metadata.jsonLd.length; i++) {
      tags.add(HeadTag(
        key: 'jsonld-$i',
        tagName: 'script',
        attributes: {'type': 'application/ld+json'},
        textContent: metadata.jsonLd[i].toSafeScriptJson(),
      ));
    }

    // Alternate Links (hreflang)
    for (final alternate in metadata.alternates) {
      tags.add(HeadTag(
        key: 'alternate-${alternate.language}',
        tagName: 'link',
        attributes: {
          'rel': 'alternate',
          'hreflang': alternate.language,
          'href': _resolveUrl(alternate.url, config.baseUrl)!,
        },
      ));
    }

    // Favicons & Web Icons
    for (var i = 0; i < metadata.icons.length; i++) {
      final icon = metadata.icons[i];
      tags.add(HeadTag(
        key: 'icon-$i-${icon.rel}',
        tagName: 'link',
        attributes: {
          'rel': icon.rel,
          'href': _resolveUrl(icon.href, config.baseUrl)!,
          if (icon.type != null) 'type': icon.type!,
          if (icon.sizes != null) 'sizes': icon.sizes!,
        },
      ));
    }

    // Resource Hints (preconnect, dns-prefetch, preload, modulepreload)
    for (var i = 0; i < metadata.resourceHints.length; i++) {
      final hint = metadata.resourceHints[i];
      tags.add(HeadTag(
        key: 'hint-$i-${hint.relation}-${hint.url}',
        tagName: 'link',
        attributes: {
          'rel': hint.relation,
          'href': _resolveUrl(hint.url, config.baseUrl)!,
          if (hint.asType != null) 'as': hint.asType!,
          if (hint.type != null) 'type': hint.type!,
          if (hint.crossOrigin != null) 'crossorigin': hint.crossOrigin!,
          if (hint.media != null) 'media': hint.media!,
        },
      ));
    }

    // Custom Meta Tags
    for (final custom in metadata.customMeta) {
      final identityCount = [custom.name, custom.property, custom.httpEquiv]
          .where((value) => value != null && value.isNotEmpty)
          .length;
      final hasBlankIdentity = [custom.name, custom.property, custom.httpEquiv]
          .any((value) => value != null && value.trim().isEmpty);
      if (custom.key.trim().isEmpty || identityCount != 1 || hasBlankIdentity) {
        throw FormatException(
            'Custom meta tags need a unique key and exactly one of name, property or httpEquiv.');
      }
      final attributes = <String, String>{'content': custom.content};
      if (custom.name != null) attributes['name'] = custom.name!;
      if (custom.property != null) attributes['property'] = custom.property!;
      if (custom.httpEquiv != null) {
        attributes['http-equiv'] = custom.httpEquiv!;
      }
      tags.add(HeadTag(
        key: 'custom-meta-${custom.key}',
        tagName: 'meta',
        attributes: attributes,
      ));
    }

    // Custom Link Tags
    for (final custom in metadata.customLinks) {
      if (custom.key.trim().isEmpty ||
          custom.rel.trim().isEmpty ||
          custom.href.trim().isEmpty) {
        throw const FormatException(
            'Custom link tags need non-empty key, rel and href values.');
      }
      tags.add(HeadTag(
        key: 'custom-link-${custom.key}',
        tagName: 'link',
        attributes: {
          'rel': custom.rel,
          'href': _resolveUrl(custom.href, config.baseUrl)!,
          if (custom.hreflang != null) 'hreflang': custom.hreflang!,
          if (custom.type != null) 'type': custom.type!,
          if (custom.media != null) 'media': custom.media!,
          if (custom.asType != null) 'as': custom.asType!,
          if (custom.crossorigin != null) 'crossorigin': custom.crossorigin!,
          if (custom.referrerpolicy != null)
            'referrerpolicy': custom.referrerpolicy!,
          if (custom.integrity != null) 'integrity': custom.integrity!,
        },
      ));
    }

    // Validate for uniqueness and consistency
    final keys = <String>{};
    final metaIdentities = <String>{};
    var canonicalLinkCount = 0;
    final alternateLanguages = <String>{};
    for (final tag in tags) {
      if (!keys.add(tag.key)) {
        throw FormatException('Duplicate metadata tag key: ${tag.key}');
      }
      if (tag.tagName == 'meta') {
        for (final identity in ['name', 'property', 'http-equiv']) {
          final value = tag.attributes[identity];
          if (value == null) continue;
          if (value.toLowerCase() == 'og:locale:alternate') break;
          final normalized = '$identity:${value.toLowerCase()}';
          if (!metaIdentities.add(normalized)) {
            throw FormatException('Duplicate meta identity: $normalized');
          }
          break;
        }
      }
      if (tag.tagName == 'link') {
        final rel = tag.attributes['rel']?.toLowerCase();
        if (rel == 'canonical') canonicalLinkCount++;
        if (rel == 'alternate') {
          final language = tag.attributes['hreflang']?.toLowerCase();
          if (language != null && !alternateLanguages.add(language)) {
            throw FormatException('Duplicate alternate language: $language');
          }
        }
      }
    }
    if (canonicalLinkCount > 1) {
      throw const FormatException('Only one canonical link can be generated.');
    }
    return List<HeadTag>.unmodifiable(tags);
  }

  String? _resolveTitle(WebMetadata metadata, MetaMantleConfig config) {
    if (metadata.title == null) {
      return config.defaultTitle ?? config.siteName;
    }

    final pageTitle = metadata.title!.trim();
    if (pageTitle.isEmpty) {
      return config.defaultTitle ?? config.siteName ?? '';
    }

    final template = config.titleTemplate;
    if (!metadata.applyTitleTemplate ||
        template == null ||
        !template.contains('%s')) {
      return pageTitle;
    }

    // Deduplication safeguards:
    // If the page title matches siteName or defaultTitle, treat it as the root title and do not duplicate.
    final siteName = config.siteName?.trim();
    final defaultTitle = config.defaultTitle?.trim();
    if ((siteName != null &&
            siteName.isNotEmpty &&
            pageTitle.toLowerCase() == siteName.toLowerCase()) ||
        (defaultTitle != null &&
            defaultTitle.isNotEmpty &&
            pageTitle.toLowerCase() == defaultTitle.toLowerCase())) {
      return pageTitle;
    }

    // Check if the template's brand suffix is already present in the title.
    final suffixIndex = template.indexOf('%s');
    final suffix = template.substring(suffixIndex + 2);
    final trimmedSuffix = suffix.trim();
    if (trimmedSuffix.isNotEmpty) {
      if (pageTitle.endsWith(trimmedSuffix)) {
        return pageTitle;
      }
      final brandPart = suffix.replaceAll(RegExp(r'^[|\-–—:\s]+'), '').trim();
      if (brandPart.isNotEmpty &&
          pageTitle.toLowerCase() == brandPart.toLowerCase()) {
        return pageTitle;
      }
    }

    // Check if the template's prefix is already present in the title.
    final prefix = template.substring(0, suffixIndex);
    final trimmedPrefix = prefix.trim();
    if (trimmedPrefix.isNotEmpty && pageTitle.startsWith(trimmedPrefix)) {
      return pageTitle;
    }

    return template.replaceAll('%s', pageTitle);
  }

  String? _applyTrailingSlash(String? url, bool? trailingSlash) {
    if (url == null || trailingSlash == null) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    // Don't modify root or paths with extensions (like .html, .png)
    if (path == '/' || path.isEmpty) return url;
    final lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final hasExtension = lastSegment.contains('.');

    if (trailingSlash) {
      if (!path.endsWith('/') && !hasExtension) {
        return uri.replace(path: '$path/').toString();
      }
    } else {
      if (path.endsWith('/') && path != '/') {
        return uri.replace(path: path.substring(0, path.length - 1)).toString();
      }
    }
    return url;
  }

  String? _resolveUrl(String? value, String? baseUrl) {
    if (value == null) return null;
    if (value.trim().isEmpty) {
      throw const FormatException('Metadata URLs must not be empty.');
    }
    final uri = Uri.tryParse(value);
    if (uri == null) throw FormatException('Invalid URL: $value');
    if (uri.hasScheme) {
      if ((uri.scheme != 'http' && uri.scheme != 'https') ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw FormatException(
            'Only absolute HTTP(S) URLs without credentials are allowed: $value');
      }
      return uri.toString();
    }
    if (uri.hasAuthority) {
      throw FormatException(
          'Protocol-relative URLs are not accepted; use an explicit HTTP(S) URL: $value');
    }
    if (baseUrl == null) return value;
    final base = Uri.parse(baseUrl);
    if ((base.scheme != 'http' && base.scheme != 'https') ||
        !base.hasAuthority ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw FormatException(
          'baseUrl must be an HTTP(S) URL without credentials, query or fragment: $baseUrl');
    }
    final normalizedBase =
        base.toString().endsWith('/') ? base : Uri.parse('${base.toString()}/');
    return normalizedBase.resolveUri(uri).toString();
  }
}
