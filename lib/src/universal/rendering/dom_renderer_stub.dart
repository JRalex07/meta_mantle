import '../ir/mantle_node.dart';
import 'renderer_contract.dart';

/// Stub DOM renderer for non-web environments (mobile, desktop, pure server).
class MantleDomRenderer implements MantleRenderer<Object> {
  const MantleDomRenderer();

  @override
  Object render(MantleNode node) {
    throw UnsupportedError(
      'MantleDomRenderer is only supported in browser environments. '
      'Use MantleServerRenderer for server HTML or MantleFlutterRenderer for native Flutter.',
    );
  }
}

class MantleHydrator {
  const MantleHydrator();

  void hydrate(Object rootElement, MantleNode node) {
    throw UnsupportedError(
        'MantleHydrator is only supported in browser environments.');
  }
}
