import '../models/metadata.dart';

/// Item availability state.
enum ItemAvailability { inStock, outOfStock, preOrder, backOrder, discontinued }

/// Item physical condition.
enum ItemCondition { newCondition, refurbishedCondition, usedCondition }

/// Shipping cost and destination specification.
class ShippingDetails {
  const ShippingDetails({
    required this.shippingRate,
    required this.currency,
    this.shippingDestination = 'US',
    this.deliveryTimeDays = 3,
  });

  final double shippingRate;
  final String currency;
  final String shippingDestination;
  final int deliveryTimeDays;

  Map<String, dynamic> toJsonLd() => {
    '@type': 'OfferShippingDetails',
    'shippingRate': {
      '@type': 'MonetaryAmount',
      'value': shippingRate.toStringAsFixed(2),
      'currency': currency,
    },
    'shippingDestination': {
      '@type': 'DefinedRegion',
      'addressCountry': shippingDestination,
    },
    'deliveryTime': {
      '@type': 'ShippingDeliveryTime',
      'transitTime': {
        '@type': 'QuantitativeValue',
        'maxValue': deliveryTimeDays,
        'unitCode': 'DAY',
      },
    },
  };
}

/// Merchant return policy specification.
class ReturnPolicy {
  const ReturnPolicy({
    this.returnPolicyCategory =
        'https://schema.org/MerchantReturnFiniteReturnWindow',
    this.merchantReturnDays = 30,
    this.returnMethod = 'https://schema.org/ReturnByMail',
    this.returnFees = 'https://schema.org/FreeReturn',
  });

  final String returnPolicyCategory;
  final int merchantReturnDays;
  final String returnMethod;
  final String returnFees;

  Map<String, dynamic> toJsonLd() => {
    '@type': 'MerchantReturnPolicy',
    'returnPolicyCategory': returnPolicyCategory,
    'merchantReturnDays': merchantReturnDays,
    'returnMethod': returnMethod,
    'returnFees': returnFees,
  };
}

/// Customer review and aggregate rating.
class ProductRating {
  const ProductRating({
    required this.ratingValue,
    required this.reviewCount,
    this.bestRating = 5.0,
    this.worstRating = 1.0,
  });

  final double ratingValue;
  final int reviewCount;
  final double bestRating;
  final double worstRating;

  Map<String, dynamic> toJsonLd() => {
    '@type': 'AggregateRating',
    'ratingValue': ratingValue.toStringAsFixed(1),
    'reviewCount': reviewCount,
    'bestRating': bestRating.toStringAsFixed(1),
    'worstRating': worstRating.toStringAsFixed(1),
  };
}

/// E-commerce product variant (e.g. Size/Color SKU).
class ProductVariant {
  const ProductVariant({
    required this.sku,
    required this.name,
    required this.price,
    this.salePrice,
    this.availability = ItemAvailability.inStock,
    this.attributes = const {},
    this.image,
  });

  final String sku;
  final String name;
  final double price;
  final double? salePrice;
  final ItemAvailability availability;
  final Map<String, String> attributes;
  final String? image;

  Map<String, dynamic> toJsonLd(String currency) => {
    '@type': 'Offer',
    'sku': sku,
    'price': (salePrice ?? price).toStringAsFixed(2),
    'priceCurrency': currency,
    'availability': _availabilitySchema(availability),
    if (image != null) 'image': image,
  };

  static String _availabilitySchema(ItemAvailability a) {
    switch (a) {
      case ItemAvailability.inStock:
        return 'https://schema.org/InStock';
      case ItemAvailability.outOfStock:
        return 'https://schema.org/OutOfStock';
      case ItemAvailability.preOrder:
        return 'https://schema.org/PreOrder';
      case ItemAvailability.backOrder:
        return 'https://schema.org/BackOrder';
      case ItemAvailability.discontinued:
        return 'https://schema.org/Discontinued';
    }
  }
}

/// Enterprise E-Commerce Product model with rich SEO structured data generation.
class ProductItem {
  const ProductItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    this.salePrice,
    this.brand,
    this.sku,
    this.gtin,
    this.category,
    this.images = const [],
    this.availability = ItemAvailability.inStock,
    this.condition = ItemCondition.newCondition,
    this.seller,
    this.rating,
    this.variants = const [],
    this.shipping,
    this.returnPolicy,
    this.tags = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final double price;
  final String currency;
  final double? salePrice;
  final String? brand;
  final String? sku;
  final String? gtin;
  final String? category;
  final List<String> images;
  final ItemAvailability availability;
  final ItemCondition condition;
  final String? seller;
  final ProductRating? rating;
  final List<ProductVariant> variants;
  final ShippingDetails? shipping;
  final ReturnPolicy? returnPolicy;
  final List<String> tags;

  /// Generates Google-compliant Schema.org Product / ProductGroup JSON-LD.
  JsonLd toJsonLd({required String baseUrl}) {
    final productUrl = '$baseUrl/products/$slug/';

    final offers = variants.isNotEmpty
        ? {
            '@type': 'AggregateOffer',
            'priceCurrency': currency,
            'lowPrice': _calculateLowPrice().toStringAsFixed(2),
            'highPrice': _calculateHighPrice().toStringAsFixed(2),
            'offerCount': variants.length,
            'offers': [for (final v in variants) v.toJsonLd(currency)],
          }
        : {
            '@type': 'Offer',
            'price': (salePrice ?? price).toStringAsFixed(2),
            'priceCurrency': currency,
            'availability': ProductVariant._availabilitySchema(availability),
            'itemCondition': _conditionSchema(condition),
            'url': productUrl,
            if (seller != null)
              'seller': {'@type': 'Organization', 'name': seller},
            if (shipping != null) 'shippingDetails': shipping!.toJsonLd(),
            if (returnPolicy != null)
              'hasMerchantReturnPolicy': returnPolicy!.toJsonLd(),
          };

    return JsonLd({
      '@context': 'https://schema.org',
      '@type': variants.isNotEmpty ? 'ProductGroup' : 'Product',
      'name': name,
      'description': description,
      'url': productUrl,
      if (images.isNotEmpty) 'image': images,
      if (brand != null) 'brand': {'@type': 'Brand', 'name': brand},
      if (sku != null) 'sku': sku,
      if (gtin != null) 'gtin': gtin,
      if (category != null) 'category': category,
      'offers': offers,
      if (rating != null) 'aggregateRating': rating!.toJsonLd(),
    });
  }

  double _calculateLowPrice() {
    if (variants.isEmpty) return salePrice ?? price;
    return variants
        .map((v) => v.salePrice ?? v.price)
        .reduce((a, b) => a < b ? a : b);
  }

  double _calculateHighPrice() {
    if (variants.isEmpty) return salePrice ?? price;
    return variants
        .map((v) => v.salePrice ?? v.price)
        .reduce((a, b) => a > b ? a : b);
  }

  static String _conditionSchema(ItemCondition c) {
    switch (c) {
      case ItemCondition.newCondition:
        return 'https://schema.org/NewCondition';
      case ItemCondition.refurbishedCondition:
        return 'https://schema.org/RefurbishedCondition';
      case ItemCondition.usedCondition:
        return 'https://schema.org/UsedCondition';
    }
  }
}
