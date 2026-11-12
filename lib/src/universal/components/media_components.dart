import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantleImage extends StatelessMantleComponent {
  const MantleImage({
    required this.src,
    this.alt = '',
    this.width,
    this.height,
    this.fit = 'cover',
    super.key,
  });

  final String src;
  final String alt;
  final double? width;
  final double? height;
  final String fit; // cover, contain, fill

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'object-fit': fit,
      'display': 'block',
    };
    if (width != null) styles['width'] = '${width}px';
    if (height != null) styles['height'] = '${height}px';

    return MantleElementNode(
      tag: 'img',
      attributes: {
        'src': src,
        'alt': alt,
      },
      styles: styles,
      key: key,
    );
  }
}

class MantleIcon extends StatelessMantleComponent {
  const MantleIcon(
    this.iconName, {
    this.size = 24.0,
    this.color,
    super.key,
  });

  final String iconName;
  final double size;
  final MantleColor? color;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'font-size': '${size}px',
      'display': 'inline-block',
      'vertical-align': 'middle',
    };
    if (color != null) styles['color'] = color!.toCssRgba();

    return MantleElementNode(
      tag: 'i',
      classes: ['mantle-icon', 'mantle-icon-$iconName'],
      styles: styles,
      children: [MantleTextNode(iconName)],
      key: key,
    );
  }
}
