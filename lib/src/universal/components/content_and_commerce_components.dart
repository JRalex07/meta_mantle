import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

/// Semantic article container component (`<article>`).
class MantleArticle extends StatelessMantleComponent {
  const MantleArticle({
    required this.children,
    this.title,
    this.author,
    this.publishedDate,
    this.padding = const MantleEdgeInsets.all(16),
    this.backgroundColor,
    super.key,
  });

  final List<MantleComponent> children;
  final String? title;
  final String? author;
  final String? publishedDate;
  final MantleEdgeInsets padding;
  final MantleColor? backgroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'box-sizing': 'border-box',
    };
    if (backgroundColor != null) {
      styles['background-color'] = backgroundColor!.toCssRgba();
    }

    final articleChildren = <MantleNode>[];
    if (title != null) {
      articleChildren.add(
        MantleElementNode(
          tag: 'header',
          children: [
            MantleElementNode(tag: 'h1', children: [MantleTextNode(title!)]),
            if (author != null || publishedDate != null)
              MantleElementNode(
                tag: 'p',
                classes: const ['mantle-article-meta'],
                styles: const {'color': '#666', 'font-size': '14px'},
                children: [
                  if (author != null) MantleTextNode('By $author '),
                  if (publishedDate != null)
                    MantleElementNode(
                      tag: 'time',
                      attributes: {'datetime': publishedDate!},
                      children: [MantleTextNode(publishedDate!)],
                    ),
                ],
              ),
          ],
        ),
      );
    }

    articleChildren.addAll(children.map((c) => c.toNode(context)));

    return MantleElementNode(
      tag: 'article',
      classes: const ['mantle-article'],
      attributes: const {'itemprop': 'articleBody'},
      styles: styles,
      children: articleChildren,
      key: key,
    );
  }
}

/// Semantic list container component (`<ul>` or `<ol>`).
class MantleList extends StatelessMantleComponent {
  const MantleList({
    required this.children,
    this.ordered = false,
    this.padding,
    super.key,
  });

  final List<MantleComponent> children;
  final bool ordered;
  final MantleEdgeInsets? padding;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{};
    if (padding != null) {
      styles['padding'] = padding!.toCssPadding();
    }

    return MantleElementNode(
      tag: ordered ? 'ol' : 'ul',
      classes: const ['mantle-list'],
      styles: styles,
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

/// Single item within a [MantleList] (`<li>`).
class MantleListItem extends StatelessMantleComponent {
  const MantleListItem({required this.child, super.key});

  final MantleComponent child;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'li',
      classes: const ['mantle-list-item'],
      children: [child.toNode(context)],
      key: key,
    );
  }
}

/// Multi-line text input component (`<textarea>`).
class MantleTextArea extends StatelessMantleComponent {
  const MantleTextArea({
    this.value = '',
    this.placeholder = '',
    this.rows = 4,
    this.cols,
    this.onChanged,
    this.padding = const MantleEdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.border = const MantleBorder.all(color: MantleColor.grey),
    this.borderRadius = const MantleBorderRadius.circular(4),
    super.key,
  });

  final String value;
  final String placeholder;
  final int rows;
  final int? cols;
  final MantleValueCallback<String>? onChanged;
  final MantleEdgeInsets padding;
  final MantleBorder border;
  final MantleBorderRadius borderRadius;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'border': border.toCss(),
      'border-radius': borderRadius.toCss(),
      'font-size': '14px',
      'outline': 'none',
      'box-sizing': 'border-box',
      'width': '100%',
      'resize': 'vertical',
    };

    final attributes = <String, String>{
      'placeholder': placeholder,
      'rows': rows.toString(),
      if (cols != null) 'cols': cols.toString(),
    };

    final events = <String, MantleEventCallback>{};
    if (onChanged != null) {
      events['input'] = (e) {
        onChanged!(e.value?.toString() ?? '');
      };
    }

    return MantleElementNode(
      tag: 'textarea',
      attributes: attributes,
      styles: styles,
      events: events,
      children: value.isNotEmpty ? [MantleTextNode(value)] : const [],
      key: key,
    );
  }
}

/// Semantic collapsible disclosure component (`<details>` and `<summary>`).
class MantleDetails extends StatelessMantleComponent {
  const MantleDetails({
    required this.summary,
    required this.content,
    this.open = false,
    this.padding = const MantleEdgeInsets.all(12),
    super.key,
  });

  final MantleComponent summary;
  final MantleComponent content;
  final bool open;
  final MantleEdgeInsets padding;

  @override
  MantleNode build(MantleContext context) {
    final attributes = <String, String>{};
    if (open) attributes['open'] = 'open';

    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'border': '1px solid #e0e0e0',
      'border-radius': '6px',
      'margin-bottom': '8px',
    };

    return MantleElementNode(
      tag: 'details',
      classes: const ['mantle-details'],
      attributes: attributes,
      styles: styles,
      children: [
        MantleElementNode(
          tag: 'summary',
          styles: const {
            'font-weight': '600',
            'cursor': 'pointer',
            'outline': 'none',
          },
          children: [summary.toNode(context)],
        ),
        MantleElementNode(
          tag: 'div',
          classes: const ['mantle-details-content'],
          styles: const {'margin-top': '8px'},
          children: [content.toNode(context)],
        ),
      ],
      key: key,
    );
  }
}

/// Rich semantic Product representation with embedded Schema.org microdata (`itemscope itemtype="https://schema.org/Product"`).
class MantleProduct extends StatelessMantleComponent {
  const MantleProduct({
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.sku,
    this.currency = 'USD',
    this.inStock = true,
    this.action,
    this.padding = const MantleEdgeInsets.all(16),
    this.border = const MantleBorder.all(color: MantleColor.grey),
    this.borderRadius = const MantleBorderRadius.circular(8),
    super.key,
  });

  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? sku;
  final String currency;
  final bool inStock;
  final MantleComponent? action;
  final MantleEdgeInsets padding;
  final MantleBorder border;
  final MantleBorderRadius borderRadius;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'border': border.toCss(),
      'border-radius': borderRadius.toCss(),
      'box-sizing': 'border-box',
    };

    final children = <MantleNode>[];

    if (imageUrl != null) {
      children.add(
        MantleElementNode(
          tag: 'img',
          attributes: {'src': imageUrl!, 'alt': name, 'itemprop': 'image'},
          styles: const {
            'max-width': '100%',
            'height': 'auto',
            'border-radius': '4px',
            'margin-bottom': '12px',
          },
        ),
      );
    }

    children.add(
      MantleElementNode(
        tag: 'h2',
        attributes: const {'itemprop': 'name'},
        styles: const {'margin': '0 0 8px 0', 'font-size': '20px'},
        children: [MantleTextNode(name)],
      ),
    );

    if (description != null) {
      children.add(
        MantleElementNode(
          tag: 'p',
          attributes: const {'itemprop': 'description'},
          styles: const {'color': '#555', 'margin': '0 0 12px 0'},
          children: [MantleTextNode(description!)],
        ),
      );
    }

    final priceStr = price.toStringAsFixed(2);
    children.add(
      MantleElementNode(
        tag: 'div',
        attributes: const {
          'itemprop': 'offers',
          'itemscope': '',
          'itemtype': 'https://schema.org/Offer',
        },
        styles: const {
          'display': 'flex',
          'align-items': 'center',
          'gap': '8px',
          'margin-bottom': '12px',
        },
        children: [
          MantleElementNode(
            tag: 'span',
            attributes: const {'itemprop': 'price'},
            styles: const {
              'font-size': '18px',
              'font-weight': 'bold',
              'color': '#2e7d32',
            },
            children: [MantleTextNode('\$$priceStr')],
          ),
          MantleElementNode(
            tag: 'meta',
            attributes: {'itemprop': 'priceCurrency', 'content': currency},
          ),
          MantleElementNode(
            tag: 'link',
            attributes: {
              'itemprop': 'availability',
              'href': inStock
                  ? 'https://schema.org/InStock'
                  : 'https://schema.org/OutOfStock',
            },
          ),
        ],
      ),
    );

    if (action != null) {
      children.add(action!.toNode(context));
    }

    final attrs = <String, String>{
      'itemscope': '',
      'itemtype': 'https://schema.org/Product',
    };
    if (sku != null) attrs['itemprop'] = 'sku';

    return MantleElementNode(
      tag: 'div',
      classes: const ['mantle-product'],
      attributes: attrs,
      styles: styles,
      children: children,
      key: key,
    );
  }
}

/// Semantic HTML Table component (`<table>`).
class MantleTable extends StatelessMantleComponent {
  const MantleTable({
    required this.rows,
    this.headers,
    this.caption,
    this.border = const MantleBorder.all(color: MantleColor.grey),
    this.padding = const MantleEdgeInsets.all(8),
    super.key,
  });

  final List<MantleTableRow> rows;
  final List<MantleTableCell>? headers;
  final String? caption;
  final MantleBorder border;
  final MantleEdgeInsets padding;

  @override
  MantleNode build(MantleContext context) {
    final tableChildren = <MantleNode>[];
    if (caption != null && caption!.isNotEmpty) {
      tableChildren.add(
        MantleElementNode(
          tag: 'caption',
          styles: const {'font-weight': 'bold', 'margin-bottom': '8px'},
          children: [MantleTextNode(caption!)],
        ),
      );
    }

    if (headers != null && headers!.isNotEmpty) {
      tableChildren.add(
        MantleElementNode(
          tag: 'thead',
          children: [
            MantleElementNode(
              tag: 'tr',
              children: headers!.map((h) => h.toNode(context)).toList(),
            ),
          ],
        ),
      );
    }

    tableChildren.add(
      MantleElementNode(
        tag: 'tbody',
        children: rows.map((r) => r.toNode(context)).toList(),
      ),
    );

    return MantleElementNode(
      tag: 'table',
      classes: const ['mantle-table'],
      styles: {
        'border-collapse': 'collapse',
        'width': '100%',
        'border': border.toCss(),
      },
      children: tableChildren,
      key: key,
    );
  }
}

/// A row inside a [MantleTable] (`<tr>`).
class MantleTableRow extends StatelessMantleComponent {
  const MantleTableRow({required this.cells, this.backgroundColor, super.key});

  final List<MantleTableCell> cells;
  final MantleColor? backgroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{};
    if (backgroundColor != null) {
      styles['background-color'] = backgroundColor!.toCssRgba();
    }
    return MantleElementNode(
      tag: 'tr',
      classes: const ['mantle-table-row'],
      styles: styles,
      children: cells.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

/// A cell inside a [MantleTableRow] (`<td>` or `<th>`).
class MantleTableCell extends StatelessMantleComponent {
  const MantleTableCell({
    required this.child,
    this.isHeader = false,
    this.colSpan,
    this.rowSpan,
    this.padding = const MantleEdgeInsets.all(8),
    this.border = const MantleBorder.all(color: MantleColor.grey),
    super.key,
  });

  const MantleTableCell.header({
    required this.child,
    this.colSpan,
    this.rowSpan,
    this.padding = const MantleEdgeInsets.all(8),
    this.border = const MantleBorder.all(color: MantleColor.grey),
    super.key,
  }) : isHeader = true;

  final MantleComponent child;
  final bool isHeader;
  final int? colSpan;
  final int? rowSpan;
  final MantleEdgeInsets padding;
  final MantleBorder border;

  @override
  MantleNode build(MantleContext context) {
    final attrs = <String, String>{};
    if (colSpan != null && colSpan! > 1) attrs['colspan'] = '$colSpan';
    if (rowSpan != null && rowSpan! > 1) attrs['rowspan'] = '$rowSpan';

    return MantleElementNode(
      tag: isHeader ? 'th' : 'td',
      classes: [isHeader ? 'mantle-th' : 'mantle-td'],
      attributes: attrs,
      styles: {
        'padding': padding.toCssPadding(),
        'border': border.toCss(),
        if (isHeader) 'font-weight': 'bold',
      },
      children: [child.toNode(context)],
      key: key,
    );
  }
}

/// Escape hatch allowing rendering of arbitrary custom HTML elements, Web Components, or SVG tags.
class MantleCustomElement extends StatelessMantleComponent {
  const MantleCustomElement({
    required this.tag,
    this.attributes = const {},
    this.styles = const {},
    this.classes = const [],
    this.children = const [],
    this.events = const {},
    super.key,
  });

  final String tag;
  final Map<String, String> attributes;
  final Map<String, String> styles;
  final List<String> classes;
  final List<MantleComponent> children;
  final Map<String, MantleEventCallback> events;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: tag,
      attributes: attributes,
      styles: styles,
      classes: classes,
      children: children.map((c) => c.toNode(context)).toList(),
      events: events,
      key: key,
    );
  }
}
