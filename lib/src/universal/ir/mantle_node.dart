import 'mantle_events.dart';
import 'mantle_style.dart';

/// Key for establishing stable identity during reconciliation across renders.
class MantleKey {
  const MantleKey(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MantleKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MantleKey($value)';
}

/// A key that uses a value of a particular type to identify itself.
class MantleValueKey<T> extends MantleKey {
  const MantleValueKey(this.typedValue) : super('$typedValue');
  final T typedValue;
}

/// Abstract base node in MetaMantle's universal intermediate representation.
abstract class MantleNode {
  const MantleNode({this.key});

  final MantleKey? key;

  T accept<T>(MantleNodeVisitor<T> visitor);
}

/// Visitor interface for traversing the MantleNode tree across different renderers.
abstract interface class MantleNodeVisitor<T> {
  T visitElement(MantleElementNode node);
  T visitText(MantleTextNode node);
  T visitFragment(MantleFragment node);
}

/// Represents an element node (such as container, button, div, section, heading, etc.).
class MantleElementNode extends MantleNode {
  const MantleElementNode({
    required this.tag,
    this.id,
    this.classes = const [],
    this.attributes = const {},
    this.styles = const {},
    this.events = const {},
    this.children = const [],
    super.key,
  });

  final String tag;
  final String? id;
  final List<String> classes;
  final Map<String, String> attributes;
  final Map<String, String> styles;
  final Map<String, MantleEventCallback> events;
  final List<MantleNode> children;

  @override
  T accept<T>(MantleNodeVisitor<T> visitor) => visitor.visitElement(this);
}

/// Represents plain or styled text in the intermediate representation.
class MantleTextNode extends MantleNode {
  const MantleTextNode(this.text, {this.style, this.tag = 'span', super.key});

  final String text;
  final MantleTextStyle? style;
  final String tag;

  @override
  T accept<T>(MantleNodeVisitor<T> visitor) => visitor.visitText(this);
}

/// Represents a collection of siblings without an enclosing wrapper.
class MantleFragment extends MantleNode {
  const MantleFragment(this.children, {super.key});

  final List<MantleNode> children;

  @override
  T accept<T>(MantleNodeVisitor<T> visitor) => visitor.visitFragment(this);
}
