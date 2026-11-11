/// Static HTML generation APIs for MetaMantle.
///
/// Import this entrypoint only from Dart command-line/build scripts. It uses
/// `dart:io` and is not intended to be imported by a Flutter browser app.
library;

export 'meta_mantle_core.dart';
export 'src/builder/incremental_manifest.dart';
export 'src/builder/static_head_builder.dart';
export 'src/builder/static_head_config.dart';
export 'src/hybrid/hybrid_generation.dart';
export 'src/seo/hreflang_validator.dart';
export 'src/seo/sitemap_index.dart';
