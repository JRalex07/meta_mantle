import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantleText extends StatelessMantleComponent {
  const MantleText(
    this.text, {
    this.style,
    this.tag = 'span',
    super.key,
  });

  final String text;
  final MantleTextStyle? style;
  final String tag;

  @override
  MantleNode build(MantleContext context) {
    return MantleTextNode(
      text,
      style: style,
      tag: tag,
      key: key,
    );
  }
}

class MantleHeading extends StatelessMantleComponent {
  const MantleHeading(
    this.text, {
    this.level = 1,
    this.style,
    super.key,
  });

  final String text;
  final int level;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final effectiveLevel = level.clamp(1, 6);
    final tag = 'h$effectiveLevel';
    final effectiveStyle = style ??
        (effectiveLevel == 1
            ? const MantleTextStyle.heading()
            : const MantleTextStyle.subheading());

    return MantleElementNode(
      tag: tag,
      styles: effectiveStyle.toCssProperties(),
      children: [MantleTextNode(text)],
      key: key,
    );
  }
}

class MantleTextSpan {
  const MantleTextSpan({
    required this.text,
    this.style,
  });

  final String text;
  final MantleTextStyle? style;
}

class MantleRichText extends StatelessMantleComponent {
  const MantleRichText({
    required this.spans,
    super.key,
  });

  final List<MantleTextSpan> spans;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: 'p',
      children:
          spans.map((s) => MantleTextNode(s.text, style: s.style)).toList(),
      key: key,
    );
  }
}
