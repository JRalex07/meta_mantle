import 'ecommerce_models.dart';

/// Generates Google Merchant Center compliant XML RSS 2.0 product feeds.
class MerchantFeedGenerator {
  const MerchantFeedGenerator({
    required this.storeName,
    required this.storeUrl,
    required this.storeDescription,
  });

  final String storeName;
  final String storeUrl;
  final String storeDescription;

  /// Emits Google-compliant RSS 2.0 XML with the `xmlns:g="http://base.google.com/ns/1.0"` namespace.
  String generateXmlFeed(List<ProductItem> products) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">');
    buf.writeln('  <channel>');
    buf.writeln('    <title>${_escape(storeName)}</title>');
    buf.writeln('    <link>${_escape(storeUrl)}</link>');
    buf.writeln('    <description>${_escape(storeDescription)}</description>');

    for (final p in products) {
      final productUrl = '$storeUrl/products/${p.slug}/';
      buf.writeln('    <item>');
      buf.writeln('      <g:id>${_escape(p.id)}</g:id>');
      buf.writeln('      <g:title>${_escape(p.name)}</g:title>');
      buf.writeln(
          '      <g:description>${_escape(p.description)}</g:description>');
      buf.writeln('      <g:link>${_escape(productUrl)}</g:link>');
      if (p.images.isNotEmpty) {
        buf.writeln(
            '      <g:image_link>${_escape(p.images.first)}</g:image_link>');
        for (final extraImg in p.images.skip(1)) {
          buf.writeln(
              '      <g:additional_image_link>${_escape(extraImg)}</g:additional_image_link>');
        }
      }
      buf.writeln(
          '      <g:condition>${_merchantCondition(p.condition)}</g:condition>');
      buf.writeln(
          '      <g:availability>${_merchantAvailability(p.availability)}</g:availability>');
      buf.writeln(
          '      <g:price>${p.price.toStringAsFixed(2)} ${p.currency}</g:price>');
      if (p.salePrice != null) {
        buf.writeln(
            '      <g:sale_price>${p.salePrice!.toStringAsFixed(2)} ${p.currency}</g:sale_price>');
      }
      if (p.brand != null) {
        buf.writeln('      <g:brand>${_escape(p.brand!)}</g:brand>');
      }
      if (p.gtin != null) {
        buf.writeln('      <g:gtin>${_escape(p.gtin!)}</g:gtin>');
      }
      if (p.sku != null) {
        buf.writeln('      <g:mpn>${_escape(p.sku!)}</g:mpn>');
      }
      if (p.category != null) {
        buf.writeln(
            '      <g:google_product_category>${_escape(p.category!)}</g:google_product_category>');
      }
      if (p.shipping != null) {
        buf.writeln('      <g:shipping>');
        buf.writeln(
            '        <g:country>${_escape(p.shipping!.shippingDestination)}</g:country>');
        buf.writeln(
            '        <g:price>${p.shipping!.shippingRate.toStringAsFixed(2)} ${p.shipping!.currency}</g:price>');
        buf.writeln('      </g:shipping>');
      }
      buf.writeln('    </item>');
    }

    buf.writeln('  </channel>');
    buf.writeln('</rss>');
    return buf.toString();
  }

  static String _merchantCondition(ItemCondition c) {
    switch (c) {
      case ItemCondition.newCondition:
        return 'new';
      case ItemCondition.refurbishedCondition:
        return 'refurbished';
      case ItemCondition.usedCondition:
        return 'used';
    }
  }

  static String _merchantAvailability(ItemAvailability a) {
    switch (a) {
      case ItemAvailability.inStock:
        return 'in_stock';
      case ItemAvailability.outOfStock:
      case ItemAvailability.discontinued:
        return 'out_of_stock';
      case ItemAvailability.preOrder:
        return 'preorder';
      case ItemAvailability.backOrder:
        return 'backorder';
    }
  }

  static String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
