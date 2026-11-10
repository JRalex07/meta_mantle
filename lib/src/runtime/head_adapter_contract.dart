import '../core/head_tag.dart';

abstract interface class HeadAdapter {
  bool get isSupported;
  void apply(List<HeadTag> tags);
  void clear();
}
