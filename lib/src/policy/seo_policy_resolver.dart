import '../models/metadata.dart';
import 'policy_provenance.dart';
import 'seo_policy.dart';

/// Container for the resolved metadata and its diagnostic provenance trace.
class ResolvedSeoMetadata {
  const ResolvedSeoMetadata({
    required this.metadata,
    required this.provenance,
  });

  final WebMetadata metadata;
  final PolicyProvenance provenance;
}

/// Centralized SEO policy resolution engine executing the 7-tier inheritance hierarchy:
/// Global -> Application -> Tenant -> Locale -> Section -> Route -> Page Overrides.
class SeoPolicyResolver {
  const SeoPolicyResolver();

  /// Resolves metadata according to the 7-tier policy inheritance rules.
  ResolvedSeoMetadata resolve({
    SeoPolicy? global,
    SeoPolicy? application,
    SeoPolicy? tenant,
    SeoPolicy? locale,
    SeoPolicy? section,
    SeoPolicy? route,
    WebMetadata? page,
    String? currentPath,
  }) {
    final chain = <SeoPolicy>[
      if (global != null) global,
      if (application != null) application,
      if (tenant != null) tenant,
      if (locale != null) locale,
      if (section != null) section,
      if (route != null) route,
    ];

    final origins = <String, PolicyTier>{};
    final conflicts = <String>[];

    // 1. Resolve Title
    String? rawTitle = page?.title;
    PolicyTier? titleOrigin = page?.title != null ? PolicyTier.page : null;

    if (rawTitle == null || rawTitle.isEmpty) {
      for (final p in chain.reversed) {
        if (p.defaultTitle != null && p.defaultTitle!.isNotEmpty) {
          rawTitle = p.defaultTitle;
          titleOrigin = p.tier;
          break;
        }
      }
    }

    // Resolve title template (most specific policy template takes precedence)
    String? titleTemplate;
    for (final p in chain.reversed) {
      if (p.titleTemplate != null && p.titleTemplate!.isNotEmpty) {
        titleTemplate = p.titleTemplate;
        break;
      }
    }

    String? finalTitle = rawTitle;
    if (finalTitle != null &&
        titleTemplate != null &&
        page?.applyTitleTemplate != false) {
      if (!finalTitle.contains('|') && !titleTemplate.startsWith(finalTitle)) {
        if (titleTemplate.contains('%s')) {
          finalTitle = titleTemplate.replaceAll('%s', finalTitle);
        } else if (titleTemplate.contains('{title}')) {
          finalTitle = titleTemplate.replaceAll('{title}', finalTitle);
        }
      }
    }
    if (titleOrigin != null) origins['title'] = titleOrigin;

    // 2. Resolve Description
    String? finalDesc = page?.description;
    PolicyTier? descOrigin = page?.description != null ? PolicyTier.page : null;

    if (finalDesc == null || finalDesc.isEmpty) {
      for (final p in chain.reversed) {
        if (p.defaultDescription != null && p.defaultDescription!.isNotEmpty) {
          finalDesc = p.defaultDescription;
          descOrigin = p.tier;
          break;
        }
      }
    }
    if (descOrigin != null) origins['description'] = descOrigin;

    // 3. Resolve Robots
    bool forceNoindex = false;
    bool forceNofollow = false;
    PolicyTier? robotsOrigin;

    for (final p in chain) {
      if (p.forceNoindex) {
        forceNoindex = true;
        robotsOrigin = p.tier;
      }
      if (p.forceNofollow) {
        forceNofollow = true;
        robotsOrigin = p.tier;
      }
    }

    String finalRobots = page?.robots ?? RobotsDirective.indexFollow;
    if (page?.robots != null) {
      robotsOrigin = PolicyTier.page;
    } else {
      for (final p in chain.reversed) {
        if (p.defaultRobots != null) {
          finalRobots = p.defaultRobots!;
          robotsOrigin ??= p.tier;
          break;
        }
      }
    }

    if (forceNoindex || forceNofollow) {
      final parts =
          finalRobots.split(',').map((e) => e.trim().toLowerCase()).toList();
      if (forceNoindex) {
        parts.remove('index');
        if (!parts.contains('noindex')) parts.insert(0, 'noindex');
      }
      if (forceNofollow) {
        parts.remove('follow');
        if (!parts.contains('nofollow')) parts.add('nofollow');
      }
      finalRobots = parts.join(', ');
      if (page?.robots != null &&
          !page!.robots!.contains('noindex') &&
          forceNoindex) {
        conflicts.add(
          'Page requested index, but ancestor policy enforced forceNoindex=true.',
        );
      }
    }
    if (robotsOrigin != null) origins['robots'] = robotsOrigin;

    // 4. Resolve Canonical URL
    String? finalCanonical = page?.canonical;
    PolicyTier? canonicalOrigin =
        page?.canonical != null ? PolicyTier.page : null;

    if (finalCanonical == null && currentPath != null) {
      String? baseUrl;
      bool? trailingSlash;
      for (final p in chain.reversed) {
        if (baseUrl == null && p.canonicalBaseUrl != null) {
          baseUrl = p.canonicalBaseUrl;
          canonicalOrigin ??= p.tier;
        }
        if (trailingSlash == null && p.enforceTrailingSlash != null) {
          trailingSlash = p.enforceTrailingSlash;
        }
      }

      if (baseUrl != null) {
        final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
        var cleanPath =
            currentPath.startsWith('/') ? currentPath : '/$currentPath';
        if (trailingSlash == true && !cleanPath.endsWith('/')) {
          cleanPath = '$cleanPath/';
        } else if (trailingSlash == false &&
            cleanPath.endsWith('/') &&
            cleanPath.length > 1) {
          cleanPath = cleanPath.substring(0, cleanPath.length - 1);
        }
        finalCanonical = '$cleanBase$cleanPath';
      }
    }
    if (canonicalOrigin != null) origins['canonical'] = canonicalOrigin;

    // 5. Resolve Social Images & Open Graph
    String? defaultImg;
    PolicyTier? imageOrigin;
    for (final p in chain.reversed) {
      if (p.defaultImage != null && p.defaultImage!.isNotEmpty) {
        defaultImg = p.defaultImage;
        imageOrigin = p.tier;
        break;
      }
    }

    OpenGraphMetadata? resolvedOg = page?.openGraph;
    if (resolvedOg == null) {
      for (final p in chain.reversed) {
        if (p.defaultOpenGraph != null) {
          resolvedOg = p.defaultOpenGraph;
          origins['openGraph'] = p.tier;
          break;
        }
      }
    }

    if (resolvedOg == null && defaultImg != null) {
      resolvedOg = OpenGraphMetadata(
        image: defaultImg,
        title: finalTitle,
        description: finalDesc,
      );
      origins['openGraph.image'] = imageOrigin!;
    } else if (resolvedOg != null &&
        (resolvedOg.image == null || resolvedOg.image!.isEmpty)) {
      if (defaultImg != null) {
        resolvedOg = resolvedOg.copyWith(image: defaultImg);
        origins['openGraph.image'] = imageOrigin!;
      }
    }

    // 6. Resolve Twitter Card
    TwitterCardMetadata? resolvedTwitter = page?.twitter;
    if (resolvedTwitter == null) {
      for (final p in chain.reversed) {
        if (p.defaultTwitter != null) {
          resolvedTwitter = p.defaultTwitter;
          origins['twitter'] = p.tier;
          break;
        }
      }
    }

    if (resolvedTwitter == null && defaultImg != null) {
      resolvedTwitter = TwitterCardMetadata(
        image: defaultImg,
        title: finalTitle,
        description: finalDesc,
      );
      origins['twitter.image'] = imageOrigin!;
    } else if (resolvedTwitter != null &&
        (resolvedTwitter.image == null || resolvedTwitter.image!.isEmpty)) {
      if (defaultImg != null) {
        resolvedTwitter = resolvedTwitter.copyWith(image: defaultImg);
        origins['twitter.image'] = imageOrigin!;
      }
    }

    // 7. Resolve JSON-LD (Chain merging)
    final mergedJsonLd = <JsonLd>[];
    for (final p in chain) {
      mergedJsonLd.addAll(p.defaultJsonLd);
    }
    if (page?.jsonLd != null) {
      mergedJsonLd.addAll(page!.jsonLd);
      origins['jsonLd'] = PolicyTier.page;
    } else if (mergedJsonLd.isNotEmpty) {
      origins['jsonLd'] = chain.last.tier;
    }

    // 8. Resolve Keywords & Authorship
    final mergedKeywords = <String>{};
    for (final p in chain) {
      mergedKeywords.addAll(p.keywords);
    }
    if (page?.keywords != null && page!.keywords!.isNotEmpty) {
      mergedKeywords.addAll(
        page.keywords!
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    String? finalAuthor = page?.author;
    for (final p in chain.reversed) {
      if (finalAuthor == null && p.author != null) {
        finalAuthor = p.author;
        origins['author'] = p.tier;
      }
    }

    final metadata = WebMetadata(
      title: finalTitle,
      description: finalDesc,
      canonical: finalCanonical,
      robots: finalRobots,
      keywords: mergedKeywords.isNotEmpty ? mergedKeywords.join(', ') : null,
      author: finalAuthor,
      openGraph: resolvedOg,
      twitter: resolvedTwitter,
      jsonLd: mergedJsonLd,
    );

    final provenance = PolicyProvenance(
      fieldOrigins: origins,
      conflicts: conflicts,
      appliedPolicies: chain,
    );

    return ResolvedSeoMetadata(metadata: metadata, provenance: provenance);
  }
}
