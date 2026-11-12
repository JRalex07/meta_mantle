/// Universal styling abstraction that maps cleanly to CSS styles on Web/Server
/// and Flutter styling properties (BoxDecoration, TextStyle, etc.) on native.
class MantleColor {
  const MantleColor(this.value);

  const MantleColor.fromARGB(int a, int r, int g, int b)
      : value = (((a & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                (b & 0xff)) &
            0xFFFFFFFF;

  MantleColor.fromRGBO(int r, int g, int b, double opacity)
      : value = ((((opacity * 0xff).round() & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                (b & 0xff)) &
            0xFFFFFFFF;

  final int value;

  int get alphaChannel => (value >> 24) & 0xff;
  int get redChannel => (value >> 16) & 0xff;
  int get greenChannel => (value >> 8) & 0xff;
  int get blueChannel => value & 0xff;

  int get alpha => alphaChannel;
  int get red => redChannel;

  static const MantleColor transparent = MantleColor(0x00000000);
  static const MantleColor black = MantleColor(0xFF000000);
  static const MantleColor white = MantleColor(0xFFFFFFFF);
  static const MantleColor grey = MantleColor(0xFF9E9E9E);
  static const MantleColor blue = MantleColor(0xFF2196F3);
  static const MantleColor green = MantleColor(0xFF4CAF50);
  static const MantleColor redColor = MantleColor(0xFFF44336);

  String toCssRgba() {
    final opacity = (alphaChannel / 255.0).toStringAsFixed(3);
    return 'rgba($redChannel, $greenChannel, $blueChannel, $opacity)';
  }

  String toCssHex() {
    final r = redChannel.toRadixString(16).padLeft(2, '0');
    final g = greenChannel.toRadixString(16).padLeft(2, '0');
    final b = blueChannel.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MantleColor && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class MantleEdgeInsets {
  const MantleEdgeInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const MantleEdgeInsets.symmetric({double vertical = 0, double horizontal = 0})
      : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  const MantleEdgeInsets.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  static const MantleEdgeInsets zero = MantleEdgeInsets.all(0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  String toCssPadding() => '${top}px ${right}px ${bottom}px ${left}px';
  String toCssMargin() => '${top}px ${right}px ${bottom}px ${left}px';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MantleEdgeInsets &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class MantleBorderRadius {
  const MantleBorderRadius.all(double radius)
      : topLeft = radius,
        topRight = radius,
        bottomLeft = radius,
        bottomRight = radius;

  const MantleBorderRadius.circular(double radius) : this.all(radius);

  const MantleBorderRadius.only({
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomLeft = 0,
    this.bottomRight = 0,
  });

  static const MantleBorderRadius zero = MantleBorderRadius.all(0);

  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;

  String toCss() =>
      '${topLeft}px ${topRight}px ${bottomRight}px ${bottomLeft}px';
}

class MantleBorder {
  const MantleBorder.all({
    this.color = MantleColor.black,
    this.width = 1.0,
  });

  final MantleColor color;
  final double width;

  String toCss() => '${width}px solid ${color.toCssRgba()}';
}

class MantleBoxShadow {
  const MantleBoxShadow({
    this.color = const MantleColor(0x33000000),
    this.offset = const MantleOffset(0, 2),
    this.blurRadius = 4.0,
    this.spreadRadius = 0.0,
  });

  final MantleColor color;
  final MantleOffset offset;
  final double blurRadius;
  final double spreadRadius;

  String toCss() =>
      '${offset.dx}px ${offset.dy}px ${blurRadius}px ${spreadRadius}px ${color.toCssRgba()}';
}

class MantleOffset {
  const MantleOffset(this.dx, this.dy);
  final double dx;
  final double dy;
}

enum MantleMainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

enum MantleCrossAxisAlignment {
  start,
  end,
  center,
  stretch,
  baseline,
}

enum MantleFontWeight {
  w100,
  w200,
  w300,
  normal,
  w500,
  w600,
  bold,
  w800,
  w900,
}

enum MantleFontStyle {
  normal,
  italic,
}

class MantleTextStyle {
  const MantleTextStyle({
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight,
    this.decoration,
  });

  const MantleTextStyle.heading({
    this.color,
    this.fontSize = 28.0,
    this.fontWeight = MantleFontWeight.bold,
    this.fontStyle,
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight = 1.3,
    this.decoration,
  });

  const MantleTextStyle.subheading({
    this.color,
    this.fontSize = 20.0,
    this.fontWeight = MantleFontWeight.w600,
    this.fontStyle,
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight = 1.4,
    this.decoration,
  });

  const MantleTextStyle.body({
    this.color,
    this.fontSize = 15.0,
    this.fontWeight = MantleFontWeight.normal,
    this.fontStyle,
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight = 1.5,
    this.decoration,
  });

  final MantleColor? color;
  final double? fontSize;
  final MantleFontWeight? fontWeight;
  final MantleFontStyle? fontStyle;
  final String? fontFamily;
  final double? letterSpacing;
  final double? lineHeight;
  final String? decoration; // underline, line-through, none

  Map<String, String> toCssProperties() {
    final map = <String, String>{};
    if (color != null) map['color'] = color!.toCssRgba();
    if (fontSize != null) map['font-size'] = '${fontSize}px';
    if (fontWeight != null) {
      map['font-weight'] = switch (fontWeight!) {
        MantleFontWeight.w100 => '100',
        MantleFontWeight.w200 => '200',
        MantleFontWeight.w300 => '300',
        MantleFontWeight.normal => '400',
        MantleFontWeight.w500 => '500',
        MantleFontWeight.w600 => '600',
        MantleFontWeight.bold => '700',
        MantleFontWeight.w800 => '800',
        MantleFontWeight.w900 => '900',
      };
    }
    if (fontStyle != null) map['font-style'] = fontStyle!.name;
    if (fontFamily != null) map['font-family'] = fontFamily!;
    if (letterSpacing != null) map['letter-spacing'] = '${letterSpacing}px';
    if (lineHeight != null) map['line-height'] = '$lineHeight';
    if (decoration != null) map['text-decoration'] = decoration!;
    return map;
  }
}
