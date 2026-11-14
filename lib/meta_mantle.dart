/// Runtime metadata management and static SEO framework for Flutter Web.
///
/// This entrypoint is safe to import from shared Flutter applications. Browser
/// DOM access is conditionally compiled and becomes a no-op on non-web targets.
library;

export 'meta_mantle_core.dart';
export 'meta_mantle_universal.dart';
export 'src/integrations/meta_mantle_navigator_observer.dart';
export 'src/runtime/meta_head.dart';
export 'src/runtime/meta_mantle.dart';
export 'src/universal/rendering/flutter_renderer.dart';
export 'src/universal/runtime/run_mantle_app.dart';
