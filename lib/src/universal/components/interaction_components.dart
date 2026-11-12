import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantleButton extends StatelessMantleComponent {
  const MantleButton({
    this.label,
    this.onPressed,
    this.child,
    this.color = MantleColor.blue,
    this.textColor = MantleColor.white,
    this.padding = const MantleEdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    this.borderRadius = const MantleBorderRadius.circular(6),
    super.key,
  });

  final String? label;
  final MantleVoidCallback? onPressed;
  final MantleComponent? child;
  final MantleColor color;
  final MantleColor textColor;
  final MantleEdgeInsets padding;
  final MantleBorderRadius borderRadius;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'background-color': color.toCssRgba(),
      'color': textColor.toCssRgba(),
      'padding': padding.toCssPadding(),
      'border-radius': borderRadius.toCss(),
      'border': 'none',
      'cursor': onPressed != null ? 'pointer' : 'default',
      'font-size': '14px',
      'font-weight': '600',
      'display': 'inline-flex',
      'align-items': 'center',
      'justify-content': 'center',
      'transition': 'background-color 0.15s ease',
    };

    final children = <MantleNode>[];
    if (child != null) {
      children.add(child!.toNode(context));
    } else if (label != null) {
      children.add(MantleTextNode(label!));
    }

    final events = <String, MantleEventCallback>{};
    if (onPressed != null) {
      events['click'] = (_) => onPressed!();
    }

    return MantleElementNode(
      tag: 'button',
      classes: const ['mantle-button'],
      styles: styles,
      events: events,
      children: children,
      key: key,
    );
  }
}

class MantleIconButton extends StatelessMantleComponent {
  const MantleIconButton({
    required this.iconName,
    required this.onPressed,
    this.color,
    this.size = 24.0,
    super.key,
  });

  final String iconName;
  final MantleVoidCallback onPressed;
  final MantleColor? color;
  final double size;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'background': 'none',
      'border': 'none',
      'padding': '8px',
      'cursor': 'pointer',
      'display': 'inline-flex',
      'align-items': 'center',
      'justify-content': 'center',
    };
    if (color != null) styles['color'] = color!.toCssRgba();

    return MantleElementNode(
      tag: 'button',
      classes: const ['mantle-icon-button'],
      styles: styles,
      events: {'click': (_) => onPressed()},
      children: [
        MantleElementNode(
          tag: 'i',
          classes: ['mantle-icon', 'mantle-icon-$iconName'],
          styles: {'font-size': '${size}px'},
          children: [MantleTextNode(iconName)],
        ),
      ],
      key: key,
    );
  }
}

class MantleLink extends StatelessMantleComponent {
  const MantleLink({
    required this.href,
    this.label,
    this.child,
    this.external = false,
    this.style,
    super.key,
  });

  final String href;
  final String? label;
  final MantleComponent? child;
  final bool external;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'text-decoration': 'none',
      'cursor': 'pointer',
      ...style?.toCssProperties() ?? {'color': '#2196f3'},
    };

    final attributes = <String, String>{'href': href};
    if (external) {
      attributes['target'] = '_blank';
      attributes['rel'] = 'noopener noreferrer';
    }

    final events = <String, MantleEventCallback>{};
    if (!external) {
      events['click'] = (e) {
        context.go(href);
      };
    }

    final children = <MantleNode>[];
    if (child != null) {
      children.add(child!.toNode(context));
    } else if (label != null) {
      children.add(MantleTextNode(label!));
    }

    return MantleElementNode(
      tag: 'a',
      attributes: attributes,
      styles: styles,
      events: events,
      children: children,
      key: key,
    );
  }
}

class MantleGestureDetector extends StatelessMantleComponent {
  const MantleGestureDetector({required this.child, this.onTap, super.key});

  final MantleComponent child;
  final MantleVoidCallback? onTap;

  @override
  MantleNode build(MantleContext context) {
    final events = <String, MantleEventCallback>{};
    if (onTap != null) {
      events['click'] = (_) => onTap!();
    }

    return MantleElementNode(
      tag: 'div',
      styles: {'cursor': onTap != null ? 'pointer' : 'default'},
      events: events,
      children: [child.toNode(context)],
      key: key,
    );
  }
}
