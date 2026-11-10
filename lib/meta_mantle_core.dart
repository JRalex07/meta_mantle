/// Core platform-independent metadata models, validation, and semantic HTML rendering.
///
/// This entrypoint is completely pure Dart: it does not depend on Flutter
/// or `dart:io`, and is safe to import from any client, server, or build script.
library;

export 'src/core/head_tag.dart';
export 'src/core/metadata_renderer.dart';
export 'src/html/html_document.dart';
export 'src/html/html_node.dart';
export 'src/html/html_sanitizer.dart';
export 'src/models/metadata.dart';
