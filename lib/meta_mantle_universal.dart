/// MetaMantle Universal Component Model and Cross-Platform Rendering Architecture.
///
/// Enables defining portable, platform-agnostic UI components that can render to:
/// 1. Native semantic DOM nodes in the browser (Mode B).
/// 2. Server-side semantic HTML documents with full SEO and Schema.org markup.
/// 3. Flutter Widget trees for iOS, Android, macOS, Windows, Linux, and Flutter Web (Mode A).
library;

export 'src/universal/accelerator/flutter_web_accelerator.dart';
export 'src/universal/components/content_and_commerce_components.dart';
export 'src/universal/components/form_components.dart';
export 'src/universal/components/interaction_components.dart';
export 'src/universal/components/layout_components.dart';
export 'src/universal/components/mantle_component.dart';
export 'src/universal/components/media_components.dart';
export 'src/universal/components/navigation_and_semantic_components.dart';
export 'src/universal/components/text_components.dart';
export 'src/universal/ir/mantle_diff.dart';
export 'src/universal/ir/mantle_events.dart';
export 'src/universal/ir/mantle_node.dart';
export 'src/universal/ir/mantle_style.dart';
export 'src/universal/rendering/renderer_contract.dart';
export 'src/universal/rendering/server_renderer.dart';
export 'src/universal/routing/mantle_route.dart';
export 'src/universal/state/mantle_state.dart';
