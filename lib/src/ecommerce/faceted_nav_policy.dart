import '../models/metadata.dart';

/// Directive decision for faceted e-commerce navigation URLs.
class FacetedUrlDecision {
  const FacetedUrlDecision({
    required this.shouldIndex,
    required this.canonicalUrl,
    this.robots = RobotsDirective.indexFollow,
    this.disallowedReason,
  });

  final bool shouldIndex;
  final String canonicalUrl;
  final String robots;
  final String? disallowedReason;
}

/// Configurable SEO policy for faceted navigation (filters, sorting, pagination).
class FacetedNavPolicy {
  const FacetedNavPolicy({
    required this.baseCategoryUrl,
    this.allowedIndexableParams = const {'brand', 'category'},
    this.canonicalizeToCategory = true,
    this.maxFilterParameters = 2,
    this.noindexPaginationAfterPage = 5,
  });

  /// The root canonical URL of the category page without query parameters.
  final String baseCategoryUrl;

  /// Parameter keys permitted to form curated indexable pages.
  final Set<String> allowedIndexableParams;

  /// Whether filtered URLs should default canonical to [baseCategoryUrl].
  final bool canonicalizeToCategory;

  /// Maximum number of combined filters before forcing `noindex, follow`.
  final int maxFilterParameters;

  /// Page threshold after which paginated results are noindexed to save crawl budget.
  final int noindexPaginationAfterPage;

  /// Evaluates an incoming faceted query map and returns canonical and indexing decisions.
  FacetedUrlDecision evaluate(Map<String, String> queryParameters) {
    final cleanBase = baseCategoryUrl.replaceAll(RegExp(r'/+$'), '');
    final pageNum = int.tryParse(queryParameters['page'] ?? '') ?? 1;

    // 1. Check deep pagination crawl budget protection
    if (pageNum > noindexPaginationAfterPage) {
      return FacetedUrlDecision(
        shouldIndex: false,
        canonicalUrl: '$cleanBase/',
        robots: RobotsDirective.noindexFollow,
        disallowedReason:
            'Deep pagination beyond page $noindexPaginationAfterPage',
      );
    }

    // 2. Filter out pagination from parameter count check
    final activeFilters = queryParameters.keys
        .where((k) => k != 'page' && k != 'sort')
        .toSet();

    // 3. Unlimited combinatorics trap prevention: If filters exceed threshold, noindex
    if (activeFilters.length > maxFilterParameters) {
      return FacetedUrlDecision(
        shouldIndex: false,
        canonicalUrl: '$cleanBase/',
        robots: RobotsDirective.noindexFollow,
        disallowedReason:
            'Active filter count (${activeFilters.length}) exceeds threshold ($maxFilterParameters)',
      );
    }

    // 4. Sorting query parameters (price_asc, newest) should never be indexed as distinct pages
    if (queryParameters.containsKey('sort')) {
      return FacetedUrlDecision(
        shouldIndex: false,
        canonicalUrl: '$cleanBase/',
        robots: RobotsDirective.noindexFollow,
        disallowedReason:
            'Sorting parameter should not produce duplicate indexable pages',
      );
    }

    // 5. Curated indexable facets (e.g. /category?brand=nike)
    final isAllowedIndexable =
        activeFilters.isNotEmpty &&
        activeFilters.every((f) => allowedIndexableParams.contains(f));

    if (isAllowedIndexable && !canonicalizeToCategory) {
      final sortedQuery = activeFilters
          .map((k) => '$k=${queryParameters[k]}')
          .join('&');
      return FacetedUrlDecision(
        shouldIndex: true,
        canonicalUrl: '$cleanBase/?$sortedQuery',
        robots: RobotsDirective.indexFollow,
      );
    }

    // Default: canonicalize to base category URL
    return FacetedUrlDecision(
      shouldIndex: activeFilters.isEmpty && pageNum == 1,
      canonicalUrl: '$cleanBase/',
      robots: RobotsDirective.indexFollow,
    );
  }
}
