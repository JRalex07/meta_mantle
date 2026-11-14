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
    this.loading = 'lazy',
    this.decoding = 'async',
    this.responsive = true,
    super.key,
  });

  final String src;
  final String alt;
  final double? width;
  final double? height;
  final String fit; // cover, contain, fill, none, scale-down
  final String loading; // lazy, eager
  final String decoding; // async, auto, sync
  final bool responsive;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{'object-fit': fit, 'display': 'block'};

    final attributes = <String, String>{
      'src': src,
      'alt': alt,
      'loading': loading,
      'decoding': decoding,
    };

    if (responsive) {
      styles['max-width'] = '100%';
      styles['height'] = 'auto';

      if (width != null) {
        styles['width'] = '${width}px';
        final w = width!.toInt() == width
            ? width!.toInt().toString()
            : width.toString();
        attributes['width'] = w;
      }
      if (height != null) {
        final h = height!.toInt() == height
            ? height!.toInt().toString()
            : height.toString();
        attributes['height'] = h;
      }
      if (width != null && height != null && height! > 0) {
        final w = width!.toInt() == width
            ? width!.toInt().toString()
            : width.toString();
        final h = height!.toInt() == height
            ? height!.toInt().toString()
            : height.toString();
        styles['aspect-ratio'] = '$w / $h';
      }
    } else {
      if (width != null) {
        styles['width'] = '${width}px';
        attributes['width'] = width!.toInt() == width
            ? width!.toInt().toString()
            : width.toString();
      }
      if (height != null) {
        styles['height'] = '${height}px';
        attributes['height'] = height!.toInt() == height
            ? height!.toInt().toString()
            : height.toString();
      }
    }

    return MantleElementNode(
      tag: 'img',
      attributes: attributes,
      styles: styles,
      key: key,
    );
  }
}

class MantleIcon extends StatelessMantleComponent {
  const MantleIcon(this.iconName, {this.size = 24.0, this.color, super.key});

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
