import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantleContainer extends StatelessMantleComponent {
  const MantleContainer({
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.border,
    this.shadow,
    this.alignment,
    super.key,
  });

  final MantleComponent? child;
  final double? width;
  final double? height;
  final MantleEdgeInsets? padding;
  final MantleEdgeInsets? margin;
  final MantleColor? color;
  final MantleBorderRadius? borderRadius;
  final MantleBorder? border;
  final MantleBoxShadow? shadow;
  final String? alignment;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{};
    if (width != null) styles['width'] = '${width}px';
    if (height != null) styles['height'] = '${height}px';
    if (padding != null) styles['padding'] = padding!.toCssPadding();
    if (margin != null) styles['margin'] = margin!.toCssMargin();
    if (color != null) styles['background-color'] = color!.toCssRgba();
    if (borderRadius != null) styles['border-radius'] = borderRadius!.toCss();
    if (border != null) styles['border'] = border!.toCss();
    if (shadow != null) styles['box-shadow'] = shadow!.toCss();
    if (alignment == 'center') {
      styles['display'] = 'flex';
      styles['justify-content'] = 'center';
      styles['align-items'] = 'center';
    }

    return MantleElementNode(
      tag: 'div',
      styles: styles,
      children: child != null ? [child!.toNode(context)] : const [],
      key: key,
    );
  }
}

class MantleRow extends StatelessMantleComponent {
  const MantleRow({
    required this.children,
    this.mainAxisAlignment = MantleMainAxisAlignment.start,
    this.crossAxisAlignment = MantleCrossAxisAlignment.center,
    this.spacing = 0.0,
    super.key,
  });

  final List<MantleComponent> children;
  final MantleMainAxisAlignment mainAxisAlignment;
  final MantleCrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'display': 'flex',
      'flex-direction': 'row',
      'justify-content': _mapJustify(mainAxisAlignment),
      'align-items': _mapAlign(crossAxisAlignment),
    };
    if (spacing > 0) styles['gap'] = '${spacing}px';

    return MantleElementNode(
      tag: 'div',
      classes: const ['mantle-row'],
      styles: styles,
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantleColumn extends StatelessMantleComponent {
  const MantleColumn({
    required this.children,
    this.mainAxisAlignment = MantleMainAxisAlignment.start,
    this.crossAxisAlignment = MantleCrossAxisAlignment.stretch,
    this.spacing = 0.0,
    super.key,
  });

  final List<MantleComponent> children;
  final MantleMainAxisAlignment mainAxisAlignment;
  final MantleCrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'display': 'flex',
      'flex-direction': 'column',
      'justify-content': _mapJustify(mainAxisAlignment),
      'align-items': _mapAlign(crossAxisAlignment),
    };
    if (spacing > 0) styles['gap'] = '${spacing}px';

    return MantleElementNode(
      tag: 'div',
      classes: const ['mantle-column'],
      styles: styles,
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantlePadding extends StatelessMantleComponent {
  const MantlePadding({
    required this.padding,
    required this.child,
    super.key,
  });

  final MantleEdgeInsets padding;
  final MantleComponent child;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {'padding': padding.toCssPadding()},
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleCenter extends StatelessMantleComponent {
  const MantleCenter({
    required this.child,
    super.key,
  });

  final MantleComponent child;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {
        'display': 'flex',
        'justify-content': 'center',
        'align-items': 'center',
        'width': '100%',
      },
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleExpanded extends StatelessMantleComponent {
  const MantleExpanded({
    required this.child,
    this.flex = 1,
    super.key,
  });

  final MantleComponent child;
  final int flex;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {'flex': '$flex 1 0%'},
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleSizedBox extends StatelessMantleComponent {
  const MantleSizedBox({
    this.width,
    this.height,
    this.child,
    super.key,
  });

  final double? width;
  final double? height;
  final MantleComponent? child;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{};
    if (width != null) styles['width'] = '${width}px';
    if (height != null) styles['height'] = '${height}px';

    return MantleElementNode(
      tag: 'div',
      styles: styles,
      children: child != null ? [child!.toNode(context)] : const [],
      key: key,
    );
  }
}

class MantleSpacer extends StatelessMantleComponent {
  const MantleSpacer({this.flex = 1, super.key});
  final int flex;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {'flex': '$flex 1 0%'},
      key: key,
    );
  }
}

class MantleWrap extends StatelessMantleComponent {
  const MantleWrap({
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    super.key,
  });

  final List<MantleComponent> children;
  final double spacing;
  final double runSpacing;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {
        'display': 'flex',
        'flex-wrap': 'wrap',
        'gap': '${runSpacing}px ${spacing}px',
      },
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantleGrid extends StatelessMantleComponent {
  const MantleGrid({
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 16.0,
    super.key,
  });

  final List<MantleComponent> children;
  final int crossAxisCount;
  final double spacing;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {
        'display': 'grid',
        'grid-template-columns': 'repeat($crossAxisCount, 1fr)',
        'gap': '${spacing}px',
      },
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantleStack extends StatelessMantleComponent {
  const MantleStack({
    required this.children,
    super.key,
  });

  final List<MantleComponent> children;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'div',
      styles: {'position': 'relative'},
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

String _mapJustify(MantleMainAxisAlignment align) => switch (align) {
      MantleMainAxisAlignment.start => 'flex-start',
      MantleMainAxisAlignment.end => 'flex-end',
      MantleMainAxisAlignment.center => 'center',
      MantleMainAxisAlignment.spaceBetween => 'space-between',
      MantleMainAxisAlignment.spaceAround => 'space-around',
      MantleMainAxisAlignment.spaceEvenly => 'space-evenly',
    };

String _mapAlign(MantleCrossAxisAlignment align) => switch (align) {
      MantleCrossAxisAlignment.start => 'flex-start',
      MantleCrossAxisAlignment.end => 'flex-end',
      MantleCrossAxisAlignment.center => 'center',
      MantleCrossAxisAlignment.stretch => 'stretch',
      MantleCrossAxisAlignment.baseline => 'baseline',
    };
