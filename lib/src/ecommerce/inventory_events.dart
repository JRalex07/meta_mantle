import 'dart:async';
import '../cache/cache_store.dart';

/// Base class for all e-commerce inventory and catalog events.
sealed class ProductInventoryEvent {
  const ProductInventoryEvent({
    required this.productId,
    required this.slug,
    this.categorySlug,
  });

  final String productId;
  final String slug;
  final String? categorySlug;

  /// Returns the specific cache tags that must be invalidated for this event.
  List<String> affectedCacheTags();

  /// Returns the route paths that should be invalidated.
  List<String> affectedRoutePaths() => [
        '/products/$slug',
        if (categorySlug != null) '/categories/$categorySlug',
      ];
}

class ProductCreated extends ProductInventoryEvent {
  const ProductCreated({
    required super.productId,
    required super.slug,
    super.categorySlug,
  });

  @override
  List<String> affectedCacheTags() => [
        'catalog',
        if (categorySlug != null) 'category:$categorySlug',
      ];
}

class ProductUpdated extends ProductInventoryEvent {
  const ProductUpdated({
    required super.productId,
    required super.slug,
    super.categorySlug,
  });

  @override
  List<String> affectedCacheTags() => [
        'product:$productId',
        'product:$slug',
        if (categorySlug != null) 'category:$categorySlug',
      ];
}

class ProductDeleted extends ProductInventoryEvent {
  const ProductDeleted({
    required super.productId,
    required super.slug,
    super.categorySlug,
  });

  @override
  List<String> affectedCacheTags() => [
        'catalog',
        'product:$productId',
        'product:$slug',
        if (categorySlug != null) 'category:$categorySlug',
      ];
}

class PriceChanged extends ProductInventoryEvent {
  const PriceChanged({
    required super.productId,
    required super.slug,
    required this.oldPrice,
    required this.newPrice,
    super.categorySlug,
  });

  final double oldPrice;
  final double newPrice;

  @override
  List<String> affectedCacheTags() => [
        'product:$productId',
        'product:$slug',
        'prices',
        if (categorySlug != null) 'category:$categorySlug',
      ];
}

class InventoryChanged extends ProductInventoryEvent {
  const InventoryChanged({
    required super.productId,
    required super.slug,
    required this.availableUnits,
    super.categorySlug,
  });

  final int availableUnits;

  @override
  List<String> affectedCacheTags() => [
        'product:$productId',
        'product:$slug',
        'inventory',
      ];
}

class ProductSlugChanged extends ProductInventoryEvent {
  const ProductSlugChanged({
    required super.productId,
    required super.slug,
    required this.newSlug,
    super.categorySlug,
  });

  final String newSlug;

  @override
  List<String> affectedCacheTags() => [
        'catalog',
        'product:$productId',
        'product:$slug',
        'product:$newSlug',
        if (categorySlug != null) 'category:$categorySlug',
      ];

  @override
  List<String> affectedRoutePaths() => [
        '/products/$slug',
        '/products/$newSlug',
        if (categorySlug != null) '/categories/$categorySlug',
      ];
}

/// Dispatches catalog events and executes granular tag-based cache invalidation.
class InventoryEventDispatcher {
  const InventoryEventDispatcher(this.cacheStore);

  final MetaMantleCacheStore cacheStore;

  /// Handles an inventory event by invalidating affected cache tags atomically.
  Future<List<String>> dispatch(ProductInventoryEvent event) async {
    final tags = event.affectedCacheTags();
    await cacheStore.deleteByTags(tags);
    return tags;
  }
}
