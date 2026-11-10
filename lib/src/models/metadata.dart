import 'dart:convert';

/// Standard robots directive values and custom builders.
class RobotsDirective {
  const RobotsDirective._();

  static const String indexFollow = 'index, follow';
  static const String noindexFollow = 'noindex, follow';
  static const String indexNofollow = 'index, nofollow';
  static const String noindexNofollow = 'noindex, nofollow';
  static const String noarchive = 'noarchive';
  static const String nosnippet = 'nosnippet';
  static const String noimageindex = 'noimageindex';

  /// Generates a customized robots directive string.
  static String custom({
    bool index = true,
    bool follow = true,
    bool noarchive = false,
    bool nosnippet = false,
    bool noimageindex = false,
    int? maxSnippet,
    String? maxImagePreview,
    int? maxVideoPreview,
  }) {
    final directives = <String>[
      index ? 'index' : 'noindex',
      follow ? 'follow' : 'nofollow',
      if (noarchive) 'noarchive',
      if (nosnippet) 'nosnippet',
      if (noimageindex) 'noimageindex',
      if (maxSnippet != null) 'max-snippet:$maxSnippet',
      if (maxImagePreview != null) 'max-image-preview:$maxImagePreview',
      if (maxVideoPreview != null) 'max-video-preview:$maxVideoPreview',
    ];
    return directives.join(', ');
  }
}

/// Global defaults used to resolve page-level metadata in MetaMantle.
class MetaMantleConfig {
  const MetaMantleConfig({
    this.siteName,
    this.baseUrl,
    this.defaultTitle,
    this.defaultDescription,
    this.defaultImage,
    this.defaultRobots = RobotsDirective.indexFollow,
    this.titleTemplate,
    this.themeColor,
    this.language = 'en',
    this.includeCurrentUrlAsCanonical = false,
    this.trailingSlash,
    this.defaultKeywords,
    this.defaultAuthor,
    this.defaultPublisher,
    this.defaultApplicationName,
    this.colorScheme,
    this.debug = false,
  });

  /// The global site or brand name.
  final String? siteName;

  /// Absolute origin or base path for URL resolution (e.g. 'https://example.com').
  final String? baseUrl;

  /// Default title when a page does not specify one.
  final String? defaultTitle;

  /// Default description when a page does not specify one.
  final String? defaultDescription;

  /// Default social image fallback.
  final String? defaultImage;

  /// Default robots directive string.
  final String? defaultRobots;

  /// Formatting template for page titles (e.g. '%s | MyStore').
  final String? titleTemplate;

  /// Default browser theme color.
  final String? themeColor;

  /// Default document language code (e.g. 'en', 'hi').
  final String? language;

  /// Whether to use the router's current URL for canonical tags when not explicitly set.
  final bool includeCurrentUrlAsCanonical;

  /// Whether canonical URLs must enforce trailing slashes.
  final bool? trailingSlash;

  /// Default keywords.
  final String? defaultKeywords;

  /// Default author.
  final String? defaultAuthor;

  /// Default publisher.
  final String? defaultPublisher;

  /// Default application name.
  final String? defaultApplicationName;

  /// Supported color scheme (e.g. 'light dark', 'only light').
  final String? colorScheme;

  /// Whether debug logging is enabled.
  final bool debug;

  factory MetaMantleConfig.fromJson(Map<String, Object?> json) {
    return MetaMantleConfig(
      siteName: json['siteName'] as String?,
      baseUrl: json['baseUrl'] as String?,
      defaultTitle: json['defaultTitle'] as String?,
      defaultDescription: json['defaultDescription'] as String?,
      defaultImage: json['defaultImage'] as String?,
      defaultRobots:
          json['defaultRobots'] as String? ?? RobotsDirective.indexFollow,
      titleTemplate: json['titleTemplate'] as String?,
      themeColor: json['themeColor'] as String?,
      language: json['language'] as String? ?? 'en',
      includeCurrentUrlAsCanonical:
          json['includeCurrentUrlAsCanonical'] as bool? ?? false,
      trailingSlash: json['trailingSlash'] as bool?,
      defaultKeywords: json['defaultKeywords'] as String?,
      defaultAuthor: json['defaultAuthor'] as String?,
      defaultPublisher: json['defaultPublisher'] as String?,
      defaultApplicationName: json['defaultApplicationName'] as String?,
      colorScheme: json['colorScheme'] as String?,
      debug: json['debug'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        if (siteName != null) 'siteName': siteName,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (defaultTitle != null) 'defaultTitle': defaultTitle,
        if (defaultDescription != null)
          'defaultDescription': defaultDescription,
        if (defaultImage != null) 'defaultImage': defaultImage,
        if (defaultRobots != null) 'defaultRobots': defaultRobots,
        if (titleTemplate != null) 'titleTemplate': titleTemplate,
        if (themeColor != null) 'themeColor': themeColor,
        if (language != null) 'language': language,
        'includeCurrentUrlAsCanonical': includeCurrentUrlAsCanonical,
        if (trailingSlash != null) 'trailingSlash': trailingSlash,
        if (defaultKeywords != null) 'defaultKeywords': defaultKeywords,
        if (defaultAuthor != null) 'defaultAuthor': defaultAuthor,
        if (defaultPublisher != null) 'defaultPublisher': defaultPublisher,
        if (defaultApplicationName != null)
          'defaultApplicationName': defaultApplicationName,
        if (colorScheme != null) 'colorScheme': colorScheme,
        'debug': debug,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetaMantleConfig &&
          runtimeType == other.runtimeType &&
          siteName == other.siteName &&
          baseUrl == other.baseUrl &&
          defaultTitle == other.defaultTitle &&
          defaultDescription == other.defaultDescription &&
          defaultImage == other.defaultImage &&
          defaultRobots == other.defaultRobots &&
          titleTemplate == other.titleTemplate &&
          themeColor == other.themeColor &&
          language == other.language &&
          includeCurrentUrlAsCanonical == other.includeCurrentUrlAsCanonical &&
          trailingSlash == other.trailingSlash &&
          defaultKeywords == other.defaultKeywords &&
          defaultAuthor == other.defaultAuthor &&
          defaultPublisher == other.defaultPublisher &&
          defaultApplicationName == other.defaultApplicationName &&
          colorScheme == other.colorScheme &&
          debug == other.debug;

  @override
  int get hashCode => Object.hashAll([
        siteName,
        baseUrl,
        defaultTitle,
        defaultDescription,
        defaultImage,
        defaultRobots,
        titleTemplate,
        themeColor,
        language,
        includeCurrentUrlAsCanonical,
        trailingSlash,
        defaultKeywords,
        defaultAuthor,
        defaultPublisher,
        defaultApplicationName,
        colorScheme,
        debug,
      ]);
}

/// Backward compatibility alias for [MetaMantleConfig].
typedef WebHeadConfig = MetaMantleConfig;

/// Page-specific metadata. Unset values inherit from [WebHeadConfig].
class WebMetadata {
  const WebMetadata({
    this.title,
    this.description,
    this.canonical,
    this.robots,
    this.keywords,
    this.author,
    this.publisher,
    this.applicationName,
    this.referrerPolicy,
    this.themeColor,
    this.colorScheme,
    this.language,
    this.openGraph,
    this.twitter,
    this.jsonLd = const [],
    this.alternates = const [],
    this.icons = const [],
    this.resourceHints = const [],
    this.customMeta = const [],
    this.customLinks = const [],
    this.googleSiteVerification,
    this.bingSiteVerification,
    this.yandexVerification,
    this.baiduVerification,
    this.applyTitleTemplate = true,
    this.trailingSlash,
  });

  final String? title;
  final String? description;
  final String? canonical;
  final String? robots;
  final String? keywords;
  final String? author;
  final String? publisher;
  final String? applicationName;
  final String? referrerPolicy;
  final String? themeColor;
  final String? colorScheme;
  final String? language;
  final OpenGraphMetadata? openGraph;
  final TwitterCardMetadata? twitter;
  final List<JsonLd> jsonLd;
  final List<AlternateLink> alternates;
  final List<WebIcon> icons;
  final List<ResourceHint> resourceHints;
  final List<WebMetaTag> customMeta;
  final List<WebLinkTag> customLinks;
  final String? googleSiteVerification;
  final String? bingSiteVerification;
  final String? yandexVerification;
  final String? baiduVerification;
  final bool applyTitleTemplate;
  final bool? trailingSlash;

  WebMetadata copyWith({
    String? title,
    String? description,
    String? canonical,
    String? robots,
    String? keywords,
    String? author,
    String? publisher,
    String? applicationName,
    String? referrerPolicy,
    String? themeColor,
    String? colorScheme,
    String? language,
    OpenGraphMetadata? openGraph,
    TwitterCardMetadata? twitter,
    List<JsonLd>? jsonLd,
    List<AlternateLink>? alternates,
    List<WebIcon>? icons,
    List<ResourceHint>? resourceHints,
    List<WebMetaTag>? customMeta,
    List<WebLinkTag>? customLinks,
    String? googleSiteVerification,
    String? bingSiteVerification,
    String? yandexVerification,
    String? baiduVerification,
    bool? applyTitleTemplate,
    bool? trailingSlash,
  }) {
    return WebMetadata(
      title: title ?? this.title,
      description: description ?? this.description,
      canonical: canonical ?? this.canonical,
      robots: robots ?? this.robots,
      keywords: keywords ?? this.keywords,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      applicationName: applicationName ?? this.applicationName,
      referrerPolicy: referrerPolicy ?? this.referrerPolicy,
      themeColor: themeColor ?? this.themeColor,
      colorScheme: colorScheme ?? this.colorScheme,
      language: language ?? this.language,
      openGraph: openGraph ?? this.openGraph,
      twitter: twitter ?? this.twitter,
      jsonLd: jsonLd ?? this.jsonLd,
      alternates: alternates ?? this.alternates,
      icons: icons ?? this.icons,
      resourceHints: resourceHints ?? this.resourceHints,
      customMeta: customMeta ?? this.customMeta,
      customLinks: customLinks ?? this.customLinks,
      googleSiteVerification:
          googleSiteVerification ?? this.googleSiteVerification,
      bingSiteVerification: bingSiteVerification ?? this.bingSiteVerification,
      yandexVerification: yandexVerification ?? this.yandexVerification,
      baiduVerification: baiduVerification ?? this.baiduVerification,
      applyTitleTemplate: applyTitleTemplate ?? this.applyTitleTemplate,
      trailingSlash: trailingSlash ?? this.trailingSlash,
    );
  }

  factory WebMetadata.fromJson(Map<String, Object?> json) {
    final og = json['openGraph'];
    final twitter = json['twitter'];
    return WebMetadata(
      title: json['title'] as String?,
      description: json['description'] as String?,
      canonical: json['canonical'] as String?,
      robots: json['robots'] as String?,
      keywords: json['keywords'] as String?,
      author: json['author'] as String?,
      publisher: json['publisher'] as String?,
      applicationName: json['applicationName'] as String?,
      referrerPolicy: json['referrerPolicy'] as String?,
      themeColor: json['themeColor'] as String?,
      colorScheme: json['colorScheme'] as String?,
      language: json['language'] as String?,
      openGraph: og is Map<String, Object?>
          ? OpenGraphMetadata.fromJson(og)
          : og is Map
              ? OpenGraphMetadata.fromJson(Map<String, Object?>.from(og))
              : null,
      twitter: twitter is Map<String, Object?>
          ? TwitterCardMetadata.fromJson(twitter)
          : twitter is Map
              ? TwitterCardMetadata.fromJson(Map<String, Object?>.from(twitter))
              : null,
      jsonLd: (json['jsonLd'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => JsonLd(Map<String, Object?>.from(item)))
          .toList(growable: false),
      alternates: (json['alternates'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => AlternateLink.fromJson(
                Map<String, Object?>.from(item),
              ))
          .toList(growable: false),
      icons: (json['icons'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => WebIcon.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
      resourceHints: (json['resourceHints'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => ResourceHint.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
      customMeta: (json['customMeta'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => WebMetaTag.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
      customLinks: (json['customLinks'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => WebLinkTag.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false),
      googleSiteVerification: json['googleSiteVerification'] as String?,
      bingSiteVerification: json['bingSiteVerification'] as String?,
      yandexVerification: json['yandexVerification'] as String?,
      baiduVerification: json['baiduVerification'] as String?,
      applyTitleTemplate: json['applyTitleTemplate'] as bool? ?? true,
      trailingSlash: json['trailingSlash'] as bool?,
    );
  }

  Map<String, Object?> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (canonical != null) 'canonical': canonical,
        if (robots != null) 'robots': robots,
        if (keywords != null) 'keywords': keywords,
        if (author != null) 'author': author,
        if (publisher != null) 'publisher': publisher,
        if (applicationName != null) 'applicationName': applicationName,
        if (referrerPolicy != null) 'referrerPolicy': referrerPolicy,
        if (themeColor != null) 'themeColor': themeColor,
        if (colorScheme != null) 'colorScheme': colorScheme,
        if (language != null) 'language': language,
        if (openGraph != null) 'openGraph': openGraph!.toJson(),
        if (twitter != null) 'twitter': twitter!.toJson(),
        if (jsonLd.isNotEmpty)
          'jsonLd': jsonLd.map((item) => item.data).toList(),
        if (alternates.isNotEmpty)
          'alternates': alternates.map((item) => item.toJson()).toList(),
        if (icons.isNotEmpty)
          'icons': icons.map((item) => item.toJson()).toList(),
        if (resourceHints.isNotEmpty)
          'resourceHints': resourceHints.map((item) => item.toJson()).toList(),
        if (customMeta.isNotEmpty)
          'customMeta': customMeta.map((item) => item.toJson()).toList(),
        if (customLinks.isNotEmpty)
          'customLinks': customLinks.map((item) => item.toJson()).toList(),
        if (googleSiteVerification != null)
          'googleSiteVerification': googleSiteVerification,
        if (bingSiteVerification != null)
          'bingSiteVerification': bingSiteVerification,
        if (yandexVerification != null)
          'yandexVerification': yandexVerification,
        if (baiduVerification != null) 'baiduVerification': baiduVerification,
        'applyTitleTemplate': applyTitleTemplate,
        if (trailingSlash != null) 'trailingSlash': trailingSlash,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebMetadata &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description &&
          canonical == other.canonical &&
          robots == other.robots &&
          keywords == other.keywords &&
          author == other.author &&
          publisher == other.publisher &&
          applicationName == other.applicationName &&
          referrerPolicy == other.referrerPolicy &&
          themeColor == other.themeColor &&
          colorScheme == other.colorScheme &&
          language == other.language &&
          openGraph == other.openGraph &&
          twitter == other.twitter &&
          _listEquals(jsonLd, other.jsonLd) &&
          _listEquals(alternates, other.alternates) &&
          _listEquals(icons, other.icons) &&
          _listEquals(resourceHints, other.resourceHints) &&
          _listEquals(customMeta, other.customMeta) &&
          _listEquals(customLinks, other.customLinks) &&
          googleSiteVerification == other.googleSiteVerification &&
          bingSiteVerification == other.bingSiteVerification &&
          yandexVerification == other.yandexVerification &&
          baiduVerification == other.baiduVerification &&
          applyTitleTemplate == other.applyTitleTemplate &&
          trailingSlash == other.trailingSlash;

  @override
  int get hashCode => Object.hashAll([
        title,
        description,
        canonical,
        robots,
        keywords,
        author,
        publisher,
        applicationName,
        referrerPolicy,
        themeColor,
        colorScheme,
        language,
        openGraph,
        twitter,
        Object.hashAll(jsonLd),
        Object.hashAll(alternates),
        Object.hashAll(icons),
        Object.hashAll(resourceHints),
        Object.hashAll(customMeta),
        Object.hashAll(customLinks),
        googleSiteVerification,
        bingSiteVerification,
        yandexVerification,
        baiduVerification,
        applyTitleTemplate,
        trailingSlash,
      ]);
}

/// Standard Open Graph object types.
class OpenGraphType {
  const OpenGraphType._();
  static const String website = 'website';
  static const String article = 'article';
  static const String book = 'book';
  static const String profile = 'profile';
  static const String musicSong = 'music.song';
  static const String musicAlbum = 'music.album';
  static const String videoMovie = 'video.movie';
  static const String product = 'product';
}

/// Open Graph metadata configuration.
class OpenGraphMetadata {
  const OpenGraphMetadata({
    this.title,
    this.description,
    this.url,
    this.image,
    this.type = OpenGraphType.website,
    this.siteName,
    this.locale,
    this.imageAlt,
    this.imageWidth,
    this.imageHeight,
    this.imageType,
    this.alternateLocales = const [],
    this.video,
    this.audio,
    this.determiner,
  });

  final String? title;
  final String? description;
  final String? url;
  final String? image;
  final String type;
  final String? siteName;
  final String? locale;
  final String? imageAlt;
  final int? imageWidth;
  final int? imageHeight;
  final String? imageType;
  final List<String> alternateLocales;
  final String? video;
  final String? audio;
  final String? determiner;

  factory OpenGraphMetadata.fromJson(Map<String, Object?> json) =>
      OpenGraphMetadata(
        title: json['title'] as String?,
        description: json['description'] as String?,
        url: json['url'] as String?,
        image: json['image'] as String?,
        type: json['type'] as String? ?? OpenGraphType.website,
        siteName: json['siteName'] as String?,
        locale: json['locale'] as String?,
        imageAlt: json['imageAlt'] as String?,
        imageWidth: json['imageWidth'] as int?,
        imageHeight: json['imageHeight'] as int?,
        imageType: json['imageType'] as String?,
        alternateLocales:
            (json['alternateLocales'] as List<Object?>? ?? const [])
                .map((e) => e.toString())
                .toList(),
        video: json['video'] as String?,
        audio: json['audio'] as String?,
        determiner: json['determiner'] as String?,
      );

  Map<String, Object?> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (image != null) 'image': image,
        'type': type,
        if (siteName != null) 'siteName': siteName,
        if (locale != null) 'locale': locale,
        if (imageAlt != null) 'imageAlt': imageAlt,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
        if (imageType != null) 'imageType': imageType,
        if (alternateLocales.isNotEmpty) 'alternateLocales': alternateLocales,
        if (video != null) 'video': video,
        if (audio != null) 'audio': audio,
        if (determiner != null) 'determiner': determiner,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenGraphMetadata &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description &&
          url == other.url &&
          image == other.image &&
          type == other.type &&
          siteName == other.siteName &&
          locale == other.locale &&
          imageAlt == other.imageAlt &&
          imageWidth == other.imageWidth &&
          imageHeight == other.imageHeight &&
          imageType == other.imageType &&
          _listEquals(alternateLocales, other.alternateLocales) &&
          video == other.video &&
          audio == other.audio &&
          determiner == other.determiner;

  @override
  int get hashCode => Object.hash(
        title,
        description,
        url,
        image,
        type,
        siteName,
        locale,
        imageAlt,
        imageWidth,
        imageHeight,
        imageType,
        Object.hashAll(alternateLocales),
        video,
        audio,
        determiner,
      );
}

/// Convenience subclass for [OpenGraphMetadata].
class OpenGraph extends OpenGraphMetadata {
  const OpenGraph({
    super.title,
    super.description,
    super.url,
    super.image,
    super.type = OpenGraphType.website,
    super.siteName,
    super.locale,
    super.imageAlt,
    super.imageWidth,
    super.imageHeight,
    super.imageType,
    super.alternateLocales,
    super.video,
    super.audio,
    super.determiner,
  });
}

/// Standard X/Twitter card types.
class TwitterCardType {
  const TwitterCardType._();
  static const String summary = 'summary';
  static const String summaryLargeImage = 'summary_large_image';
  static const String player = 'player';
  static const String app = 'app';
}

/// X/Twitter card metadata configuration.
class TwitterCardMetadata {
  const TwitterCardMetadata({
    this.card = TwitterCardType.summaryLargeImage,
    this.title,
    this.description,
    this.image,
    this.imageAlt,
    this.site,
    this.creator,
  });

  final String card;
  final String? title;
  final String? description;
  final String? image;
  final String? imageAlt;
  final String? site;
  final String? creator;

  factory TwitterCardMetadata.fromJson(Map<String, Object?> json) =>
      TwitterCardMetadata(
        card: json['card'] as String? ?? TwitterCardType.summaryLargeImage,
        title: json['title'] as String?,
        description: json['description'] as String?,
        image: json['image'] as String?,
        imageAlt: json['imageAlt'] as String?,
        site: json['site'] as String?,
        creator: json['creator'] as String?,
      );

  Map<String, Object?> toJson() => {
        'card': card,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
        if (imageAlt != null) 'imageAlt': imageAlt,
        if (site != null) 'site': site,
        if (creator != null) 'creator': creator,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TwitterCardMetadata &&
          runtimeType == other.runtimeType &&
          card == other.card &&
          title == other.title &&
          description == other.description &&
          image == other.image &&
          imageAlt == other.imageAlt &&
          site == other.site &&
          creator == other.creator;

  @override
  int get hashCode => Object.hash(
        card,
        title,
        description,
        image,
        imageAlt,
        site,
        creator,
      );
}

/// Convenience subclass for [TwitterCardMetadata].
class TwitterCard extends TwitterCardMetadata {
  const TwitterCard({
    super.card = TwitterCardType.summaryLargeImage,
    super.title,
    super.description,
    super.image,
    super.imageAlt,
    super.site,
    super.creator,
  });
}

/// Structured data payload for search crawlers.
class JsonLd {
  JsonLd(Map<String, Object?> data)
      : data = Map<String, Object?>.unmodifiable(data);

  final Map<String, Object?> data;

  factory JsonLd.custom(Map<String, Object?> data) => JsonLd(data);

  factory JsonLd.organization({
    required String name,
    required String url,
    String? logo,
    List<String> sameAs = const [],
    String? telephone,
    String? email,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Organization',
        'name': name,
        'url': url,
        if (logo != null) 'logo': logo,
        if (sameAs.isNotEmpty) 'sameAs': sameAs,
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
      });

  factory JsonLd.website({
    required String name,
    required String url,
    String? description,
    String? language,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        'name': name,
        'url': url,
        if (description != null) 'description': description,
        if (language != null) 'inLanguage': language,
      });

  factory JsonLd.webPage({
    required String name,
    required String url,
    String? description,
    String? inLanguage,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'WebPage',
        'name': name,
        'url': url,
        if (description != null) 'description': description,
        if (inLanguage != null) 'inLanguage': inLanguage,
      });

  factory JsonLd.product({
    required String name,
    required String image,
    String? description,
    String? sku,
    String? brand,
    String? url,
    Map<String, Object?>? offers,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': name,
        'image': image,
        if (description != null) 'description': description,
        if (sku != null) 'sku': sku,
        if (brand != null) 'brand': {'@type': 'Brand', 'name': brand},
        if (url != null) 'url': url,
        if (offers != null) 'offers': offers,
      });

  factory JsonLd.article({
    required String headline,
    required String image,
    required String datePublished,
    String? dateModified,
    String? author,
    String? publisher,
    String? url,
    String? description,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Article',
        'headline': headline,
        'image': image,
        'datePublished': datePublished,
        if (dateModified != null) 'dateModified': dateModified,
        if (author != null) 'author': {'@type': 'Person', 'name': author},
        if (publisher != null)
          'publisher': {'@type': 'Organization', 'name': publisher},
        if (url != null) 'mainEntityOfPage': url,
        if (description != null) 'description': description,
      });

  factory JsonLd.breadcrumb(List<Map<String, String>> items) => JsonLd({
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        'itemListElement': [
          for (var i = 0; i < items.length; i++)
            {
              '@type': 'ListItem',
              'position': i + 1,
              'name': items[i]['name'],
              if (items[i]['url'] != null) 'item': items[i]['url'],
            },
        ],
      });

  factory JsonLd.localBusiness({
    required String name,
    required String address,
    String? telephone,
    String? image,
    String? url,
    String? priceRange,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'LocalBusiness',
        'name': name,
        'address': address,
        if (telephone != null) 'telephone': telephone,
        if (image != null) 'image': image,
        if (url != null) 'url': url,
        if (priceRange != null) 'priceRange': priceRange,
      });

  factory JsonLd.faqPage(List<({String question, String answer})> questions) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        'mainEntity': [
          for (final q in questions)
            {
              '@type': 'Question',
              'name': q.question,
              'acceptedAnswer': {
                '@type': 'Answer',
                'text': q.answer,
              },
            },
        ],
      });

  factory JsonLd.person({
    required String name,
    String? url,
    String? jobTitle,
    String? image,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Person',
        'name': name,
        if (url != null) 'url': url,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (image != null) 'image': image,
      });

  factory JsonLd.softwareApplication({
    required String name,
    required String operatingSystem,
    required String applicationCategory,
    Map<String, Object?>? offers,
    String? aggregateRating,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        'name': name,
        'operatingSystem': operatingSystem,
        'applicationCategory': applicationCategory,
        if (offers != null) 'offers': offers,
        if (aggregateRating != null)
          'aggregateRating': {
            '@type': 'AggregateRating',
            'ratingValue': aggregateRating,
          },
      });

  factory JsonLd.event({
    required String name,
    required String startDate,
    String? endDate,
    required String locationName,
    String? description,
    String? url,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Event',
        'name': name,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'location': {
          '@type': 'Place',
          'name': locationName,
        },
        if (description != null) 'description': description,
        if (url != null) 'url': url,
      });

  factory JsonLd.offer({
    required String price,
    required String priceCurrency,
    String? availability,
    String? url,
  }) =>
      JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Offer',
        'price': price,
        'priceCurrency': priceCurrency,
        if (availability != null) 'availability': availability,
        if (url != null) 'url': url,
      });

  /// Escapes JSON for embedding safely within an HTML <script> tag.
  String toSafeScriptJson() {
    return jsonEncode(data)
        .replaceAll('&', r'\u0026')
        .replaceAll('<', r'\u003C')
        .replaceAll('>', r'\u003E')
        .replaceAll('\u2028', r'\u2028')
        .replaceAll('\u2029', r'\u2029');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonLd &&
          runtimeType == other.runtimeType &&
          _mapEquals(data, other.data);

  @override
  int get hashCode =>
      Object.hashAll(data.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Alternative language representation for hreflang links.
class AlternateLink {
  const AlternateLink({required this.language, required this.url});
  final String language;
  final String url;

  factory AlternateLink.fromJson(Map<String, Object?> json) => AlternateLink(
        language: json['language'] as String,
        url: json['url'] as String,
      );

  Map<String, Object?> toJson() => {'language': language, 'url': url};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlternateLink &&
          runtimeType == other.runtimeType &&
          language == other.language &&
          url == other.url;

  @override
  int get hashCode => Object.hash(language, url);
}

/// Convenience subclass/alias for [AlternateLink].
class AlternateUrl extends AlternateLink {
  const AlternateUrl({required super.language, required super.url});
}

/// Icon representation for favicons, touch icons, and web manifests.
class WebIcon {
  const WebIcon({required this.href, this.rel = 'icon', this.type, this.sizes});
  final String href;
  final String rel;
  final String? type;
  final String? sizes;

  factory WebIcon.favicon(String href) => WebIcon(href: href, rel: 'icon');

  factory WebIcon.png(String href, {String? sizes}) =>
      WebIcon(href: href, rel: 'icon', type: 'image/png', sizes: sizes);

  factory WebIcon.svg(String href) =>
      WebIcon(href: href, rel: 'icon', type: 'image/svg+xml');

  factory WebIcon.appleTouchIcon(String href, {String? sizes}) =>
      WebIcon(href: href, rel: 'apple-touch-icon', sizes: sizes);

  factory WebIcon.manifest(String href) => WebIcon(href: href, rel: 'manifest');

  factory WebIcon.fromJson(Map<String, Object?> json) => WebIcon(
        href: json['href'] as String,
        rel: json['rel'] as String? ?? 'icon',
        type: json['type'] as String?,
        sizes: json['sizes'] as String?,
      );

  Map<String, Object?> toJson() => {
        'href': href,
        'rel': rel,
        if (type != null) 'type': type,
        if (sizes != null) 'sizes': sizes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebIcon &&
          runtimeType == other.runtimeType &&
          href == other.href &&
          rel == other.rel &&
          type == other.type &&
          sizes == other.sizes;

  @override
  int get hashCode => Object.hash(href, rel, type, sizes);
}

/// Resource hints for high-performance resource preloading and connection warmup.
class ResourceHint {
  const ResourceHint({
    required this.url,
    required this.relation,
    this.asType,
    this.type,
    this.crossOrigin,
    this.media,
  });

  final String url;
  final String relation; // preconnect, dns-prefetch, preload, modulepreload
  final String? asType; // script, style, image, font, fetch
  final String? type;
  final String? crossOrigin;
  final String? media;

  factory ResourceHint.preconnect(String url, {bool crossOrigin = true}) =>
      ResourceHint(
        url: url,
        relation: 'preconnect',
        crossOrigin: crossOrigin ? '' : null,
      );

  factory ResourceHint.dnsPrefetch(String url) =>
      ResourceHint(url: url, relation: 'dns-prefetch');

  factory ResourceHint.preload(
    String url, {
    required String asType,
    String? type,
    String? crossOrigin,
    String? media,
  }) =>
      ResourceHint(
        url: url,
        relation: 'preload',
        asType: asType,
        type: type,
        crossOrigin: crossOrigin,
        media: media,
      );

  factory ResourceHint.modulePreload(String url) =>
      ResourceHint(url: url, relation: 'modulepreload');

  factory ResourceHint.fromJson(Map<String, Object?> json) => ResourceHint(
        url: json['url'] as String,
        relation: json['relation'] as String,
        asType: json['asType'] as String?,
        type: json['type'] as String?,
        crossOrigin: json['crossOrigin'] as String?,
        media: json['media'] as String?,
      );

  Map<String, Object?> toJson() => {
        'url': url,
        'relation': relation,
        if (asType != null) 'asType': asType,
        if (type != null) 'type': type,
        if (crossOrigin != null) 'crossOrigin': crossOrigin,
        if (media != null) 'media': media,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceHint &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          relation == other.relation &&
          asType == other.asType &&
          type == other.type &&
          crossOrigin == other.crossOrigin &&
          media == other.media;

  @override
  int get hashCode =>
      Object.hash(url, relation, asType, type, crossOrigin, media);
}

/// Safe custom metadata. Only standard text attributes are supported.
class WebMetaTag {
  const WebMetaTag({
    required this.key,
    required this.content,
    this.name,
    this.property,
    this.httpEquiv,
  });

  final String key;
  final String content;
  final String? name;
  final String? property;
  final String? httpEquiv;

  factory WebMetaTag.fromJson(Map<String, Object?> json) => WebMetaTag(
        key: json['key'] as String,
        content: json['content'] as String,
        name: json['name'] as String?,
        property: json['property'] as String?,
        httpEquiv: json['httpEquiv'] as String?,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'content': content,
        if (name != null) 'name': name,
        if (property != null) 'property': property,
        if (httpEquiv != null) 'httpEquiv': httpEquiv,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebMetaTag &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          content == other.content &&
          name == other.name &&
          property == other.property &&
          httpEquiv == other.httpEquiv;

  @override
  int get hashCode => Object.hash(key, content, name, property, httpEquiv);
}

/// Safe custom link tag representation.
class WebLinkTag {
  const WebLinkTag({
    required this.key,
    required this.rel,
    required this.href,
    this.hreflang,
    this.type,
    this.media,
    this.asType,
    this.crossorigin,
    this.referrerpolicy,
    this.integrity,
  });

  final String key;
  final String rel;
  final String href;
  final String? hreflang;
  final String? type;
  final String? media;
  final String? asType;
  final String? crossorigin;
  final String? referrerpolicy;
  final String? integrity;

  factory WebLinkTag.fromJson(Map<String, Object?> json) => WebLinkTag(
        key: json['key'] as String,
        rel: json['rel'] as String,
        href: json['href'] as String,
        hreflang: json['hreflang'] as String?,
        type: json['type'] as String?,
        media: json['media'] as String?,
        asType: json['asType'] as String?,
        crossorigin: json['crossorigin'] as String?,
        referrerpolicy: json['referrerpolicy'] as String?,
        integrity: json['integrity'] as String?,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'rel': rel,
        'href': href,
        if (hreflang != null) 'hreflang': hreflang,
        if (type != null) 'type': type,
        if (media != null) 'media': media,
        if (asType != null) 'asType': asType,
        if (crossorigin != null) 'crossorigin': crossorigin,
        if (referrerpolicy != null) 'referrerpolicy': referrerpolicy,
        if (integrity != null) 'integrity': integrity,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebLinkTag &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          rel == other.rel &&
          href == other.href &&
          hreflang == other.hreflang &&
          type == other.type &&
          media == other.media &&
          asType == other.asType &&
          crossorigin == other.crossorigin &&
          referrerpolicy == other.referrerpolicy &&
          integrity == other.integrity;

  @override
  int get hashCode => Object.hash(
        key,
        rel,
        href,
        hreflang,
        type,
        media,
        asType,
        crossorigin,
        referrerpolicy,
        integrity,
      );
}

/// Convenience subclass/alias for [WebLinkTag].
class WebLink extends WebLinkTag {
  const WebLink({
    required super.key,
    required super.rel,
    required super.href,
    super.hreflang,
    super.type,
    super.media,
    super.asType,
    super.crossorigin,
    super.referrerpolicy,
    super.integrity,
  });
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final valA = a[key];
    final valB = b[key];
    if (valA is Map<String, Object?> && valB is Map<String, Object?>) {
      if (!_mapEquals(valA, valB)) return false;
    } else if (valA is List && valB is List) {
      if (!_listEquals(valA, valB)) return false;
    } else if (valA != valB) {
      return false;
    }
  }
  return true;
}
