import '../ir/mantle_node.dart';

/// Abstract contract for a rendering backend capable of turning a [MantleNode]
/// into a target platform visual or document tree of type [T].
abstract interface class MantleRenderer<T> {
  T render(MantleNode node);
}
