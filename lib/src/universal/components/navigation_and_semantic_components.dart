import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantlePage extends StatelessMantleComponent {
  const MantlePage({
    required this.children,
    this.title,
    this.description,
    this.padding = const MantleEdgeInsets.all(16),
    this.backgroundColor,
    super.key,
  });

  final List<MantleComponent> children;
  final String? title;
  final String? description;
  final MantleEdgeInsets padding;
  final MantleColor? backgroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'min-height': '100vh',
      'box-sizing': 'border-box',
    };
    if (backgroundColor != null) {
      styles['background-color'] = backgroundColor!.toCssRgba();
    }

    return MantleElementNode(
      tag: 'main',
      classes: const ['mantle-page'],
      styles: styles,
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantleAppBar extends StatelessMantleComponent {
  const MantleAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.backgroundColor = MantleColor.blue,
    this.foregroundColor = MantleColor.white,
    super.key,
  });

  final String title;
  final MantleComponent? leading;
  final List<MantleComponent> actions;
  final MantleColor backgroundColor;
  final MantleColor foregroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'padding': '12px 20px',
      'background-color': backgroundColor.toCssRgba(),
      'color': foregroundColor.toCssRgba(),
      'box-shadow': '0 2px 4px rgba(0,0,0,0.1)',
    };

    final leftGroup = <MantleNode>[];
    if (leading != null) leftGroup.add(leading!.toNode(context));
    leftGroup.add(
      MantleElementNode(
        tag: 'h1',
        styles: {
          'font-size': '20px',
          'margin': '0',
          'font-weight': 'bold',
        },
        children: [MantleTextNode(title)],
      ),
    );

    return MantleElementNode(
      tag: 'header',
      classes: const ['mantle-app-bar'],
      styles: styles,
      children: [
        MantleElementNode(
          tag: 'div',
          styles: {
            'display': 'flex',
            'align-items': 'center',
            'gap': '12px',
          },
          children: leftGroup,
        ),
        MantleElementNode(
          tag: 'div',
          styles: {
            'display': 'flex',
            'align-items': 'center',
            'gap': '12px',
          },
          children: actions.map((a) => a.toNode(context)).toList(),
        ),
      ],
      key: key,
    );
  }
}

class MantleRouteLink extends StatelessMantleComponent {
  const MantleRouteLink({
    required this.path,
    this.label,
    this.child,
    this.style,
    super.key,
  });

  final String path;
  final String? label;
  final MantleComponent? child;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'text-decoration': 'none',
      'cursor': 'pointer',
      ...style?.toCssProperties() ?? {'color': '#2196f3'},
    };

    final children = <MantleNode>[];
    if (child != null) {
      children.add(child!.toNode(context));
    } else if (label != null) {
      children.add(MantleTextNode(label!));
    }

    return MantleElementNode(
      tag: 'a',
      attributes: {'href': path},
      styles: styles,
      events: {
        'click': (e) {
          context.go(path);
        },
      },
      children: children,
      key: key,
    );
  }
}

enum MantleLandmarkType {
  header,
  nav,
  main,
  footer,
  aside,
  section,
  article,
}

class MantleLandmark extends StatelessMantleComponent {
  const MantleLandmark({
    required this.type,
    required this.child,
    this.id,
    this.classes = const [],
    super.key,
  });

  final MantleLandmarkType type;
  final MantleComponent child;
  final String? id;
  final List<String> classes;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: type.name,
      id: id,
      classes: classes,
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleSemantics extends StatelessMantleComponent {
  const MantleSemantics({
    required this.child,
    this.label,
    this.role,
    this.liveRegion,
    super.key,
  });

  final MantleComponent child;
  final String? label;
  final String? role;
  final String? liveRegion;

  @override
  MantleNode build(MantleContext context) {
    final attrs = <String, String>{};
    if (label != null) attrs['aria-label'] = label!;
    if (role != null) attrs['role'] = role!;
    if (liveRegion != null) attrs['aria-live'] = liveRegion!;

    return MantleElementNode(
      tag: 'div',
      attributes: attrs,
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleLabel extends StatelessMantleComponent {
  const MantleLabel(
    this.text, {
    this.forId,
    this.style,
    super.key,
  });

  final String text;
  final String? forId;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final attrs = <String, String>{};
    if (forId != null) attrs['for'] = forId!;

    return MantleElementNode(
      tag: 'label',
      attributes: attrs,
      styles: style?.toCssProperties() ?? const {},
      children: [MantleTextNode(text)],
      key: key,
    );
  }
}
