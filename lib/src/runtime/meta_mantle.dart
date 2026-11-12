import '../models/metadata.dart';
import 'runtime_coordinator.dart';

/// Imperative entry point for global configuration and metadata updates in MetaMantle.
class MetaMantle {
  MetaMantle._();

  static RuntimeCoordinator get _coordinator => RuntimeCoordinator.instance;
  static const Object _imperativeOwner = 'meta_mantle.imperative';

  /// Configures defaults. Call before `runApp` when possible.
  static void initialize({required MetaMantleConfig config}) {
    _coordinator.initialize(config);
  }

  /// Imperatively updates the document title.
  static void setTitle(String title) {
    _coordinator.setTitle(title);
  }

  /// Imperatively updates the document description.
  static void setDescription(String description) {
    _coordinator.setDescription(description);
  }

  /// Imperatively updates the document canonical URL.
  static void setCanonical(String canonical) {
    _coordinator.setCanonical(canonical);
  }

  /// Applies or replaces an imperative metadata scope.
  static void update(WebMetadata metadata) {
    _coordinator.activate(_imperativeOwner, metadata);
  }

  /// Updates the URL used when `includeCurrentUrlAsCanonical` is enabled.
  /// Usually unnecessary; a route integration may call this on navigation.
  static void setCurrentUrl(String? url) {
    _coordinator.setCurrentUrl(url);
  }

  /// Removes the imperative scope and restores the next active widget scope.
  static void clearUpdate() {
    _coordinator.remove(_imperativeOwner);
  }

  /// Clears all package-managed tags. Does not change unrelated head elements.
  static void reset() {
    _coordinator.clear();
  }

  /// Signals to the static HTML snapshot and bootstrap coordinator that the Flutter
  /// application has rendered its initial frame and is ready for user interaction.
  /// Transitions away the static HTML pre-render snapshot gracefully.
  static void markReady() {
    _coordinator.markReady();
  }

  static MetaMantleConfig get config => _coordinator.config;
  static bool get isSupported => _coordinator.isSupported;
  static WebMetadata? get activeMetadata => _coordinator.activeMetadata;
  static int get generationToken => _coordinator.generationToken;
}

/// Backward compatibility alias for [MetaMantle].
typedef FlutterWebHead = MetaMantle;
