import '../core/head_tag.dart';
import 'head_adapter_contract.dart';

HeadAdapter createHeadAdapter() => const _StubHeadAdapter();

class _StubHeadAdapter implements HeadAdapter {
  const _StubHeadAdapter();
  @override
  bool get isSupported => false;
  @override
  void apply(List<HeadTag> tags) {}
  @override
  void clear() {}
}
