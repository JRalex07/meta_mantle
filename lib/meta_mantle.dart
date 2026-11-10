/// Runtime metadata management and static SEO framework for Flutter Web.
///
/// This entrypoint is safe to import from shared Flutter applications. Browser
/// DOM access is conditionally compiled and becomes a no-op on non-web targets.
library;

export 'src/integrations/meta_mantle_navigator_observer.dart';
export 'src/models/metadata.dart';
export 'src/runtime/meta_head.dart';
export 'src/runtime/meta_mantle.dart';
