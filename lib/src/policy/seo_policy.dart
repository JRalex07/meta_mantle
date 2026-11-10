import '../models/metadata.dart';

/// Defines the policy tier in the 7-level inheritance hierarchy.
enum PolicyTier {
  global,
  application,
  tenant,
  locale,
  section,
  route,
  page,
}

/// A policy node declaring SEO rules, defaults, and overrides at a specific tier.
class SeoPolicy {
  const SeoPolicy({
    this.name,
    this.tier = PolicyTier.global,
    this.titleTemplate,
    this.defaultTitle,
    this.defaultDescription,
    this.descriptionTemplate,
    this.canonicalBaseUrl,
    this.enforceTrailingSlash,
    this.defaultRobots,
    this.forceNoindex = false,
    this.forceNofollow = false,
    this.defaultImage,
    this.defaultImageAlt,
    this.defaultOpenGraph,
    this.defaultTwitter,
    this.defaultJsonLd = const [],
    this.localeAlternates = const {},
    this.customMetaTags = const {},
    this.keywords = const [],
    this.author,
    this.publisher,
    this.themeColor,
  });

  final String? name;
  final PolicyTier tier;
  final String? titleTemplate;
  final String? defaultTitle;
  final String? defaultDescription;
  final String? descriptionTemplate;
  final String? canonicalBaseUrl;
  final bool? enforceTrailingSlash;
  final String? defaultRobots;
  final bool forceNoindex;
  final bool forceNofollow;
  final String? defaultImage;
  final String? defaultImageAlt;
  final OpenGraphMetadata? defaultOpenGraph;
  final TwitterCardMetadata? defaultTwitter;
  final List<JsonLd> defaultJsonLd;
  final Map<String, String> localeAlternates;
  final Map<String, String> customMetaTags;
  final List<String> keywords;
  final String? author;
  final String? publisher;
  final String? themeColor;

  SeoPolicy copyWith({
    String? name,
    PolicyTier? tier,
    String? titleTemplate,
    String? defaultTitle,
    String? defaultDescription,
    String? descriptionTemplate,
    String? canonicalBaseUrl,
    bool? enforceTrailingSlash,
    String? defaultRobots,
    bool? forceNoindex,
    bool? forceNofollow,
    String? defaultImage,
    String? defaultImageAlt,
    OpenGraphMetadata? defaultOpenGraph,
    TwitterCardMetadata? defaultTwitter,
    List<JsonLd>? defaultJsonLd,
    Map<String, String>? localeAlternates,
    Map<String, String>? customMetaTags,
    List<String>? keywords,
    String? author,
    String? publisher,
    String? themeColor,
  }) {
    return SeoPolicy(
      name: name ?? this.name,
      tier: tier ?? this.tier,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      defaultTitle: defaultTitle ?? this.defaultTitle,
      defaultDescription: defaultDescription ?? this.defaultDescription,
      descriptionTemplate: descriptionTemplate ?? this.descriptionTemplate,
      canonicalBaseUrl: canonicalBaseUrl ?? this.canonicalBaseUrl,
      enforceTrailingSlash: enforceTrailingSlash ?? this.enforceTrailingSlash,
      defaultRobots: defaultRobots ?? this.defaultRobots,
      forceNoindex: forceNoindex ?? this.forceNoindex,
      forceNofollow: forceNofollow ?? this.forceNofollow,
      defaultImage: defaultImage ?? this.defaultImage,
      defaultImageAlt: defaultImageAlt ?? this.defaultImageAlt,
      defaultOpenGraph: defaultOpenGraph ?? this.defaultOpenGraph,
      defaultTwitter: defaultTwitter ?? this.defaultTwitter,
      defaultJsonLd: defaultJsonLd ?? this.defaultJsonLd,
      localeAlternates: localeAlternates ?? this.localeAlternates,
      customMetaTags: customMetaTags ?? this.customMetaTags,
      keywords: keywords ?? this.keywords,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}
