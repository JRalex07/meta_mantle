import '../ir/mantle_node.dart';
import 'mantle_component.dart';

/// Represents a scoped Flutter Island mount container in hybrid rendering (Strategy C: [RenderingStrategy.domWithFlutterIslands]).
///
/// In Strategy C, the primary page document is rendered as native semantic HTML,
/// while Flutter is initialized and scoped strictly inside this container element using its [id].
///
/// If Flutter runtime is loading or fails to initialize, [fallbackChild] remains visible.
class MantleIsland extends StatelessMantleComponent {
  const MantleIsland({
    required this.id,
    this.name,
    this.fallbackChild,
    this.className,
    this.attributes = const {},
    this.style,
    this.width,
    this.height,
    super.key,
  });

  /// The unique DOM element ID of the host container (e.g. 'flutter-cart-island').
  final String id;

  /// Optional semantic name or feature tag of the island.
  final String? name;

  /// Optional fallback component displayed before or in the absence of Flutter mounting.
  final MantleComponent? fallbackChild;

  /// Additional CSS classes.
  final String? className;

  /// Additional HTML attributes.
  final Map<String, String> attributes;

  /// Inline styles for the island container.
  final Map<String, String>? style;

  /// Explicit container width in pixels.
  final double? width;

  /// Explicit container height in pixels.
  final double? height;

  @override
  MantleNode build(MantleContext context) {
    final mergedStyles = <String, String>{
      if (width != null) 'width': '${width}px',
      if (height != null) 'height': '${height}px',
      'min-height': height != null ? '${height}px' : '48px',
      'position': 'relative',
      'box-sizing': 'border-box',
      if (style != null) ...style!,
    };

    final classes = [
      'mantle-flutter-island',
      if (className != null && className!.isNotEmpty) className!,
    ];

    final mergedAttrs = <String, String>{
      'id': id,
      'data-mantle-island': name ?? id,
      'role': 'region',
      'aria-label': 'Interactive Flutter Island: ${name ?? id}',
      ...attributes,
    };

    final children = <MantleNode>[];
    if (fallbackChild != null) {
      children.add(fallbackChild!.toNode(context));
    }

    return MantleElementNode(
      tag: 'div',
      id: id,
      classes: classes,
      attributes: mergedAttrs,
      styles: mergedStyles,
      children: children,
      key: key,
    );
  }
}
