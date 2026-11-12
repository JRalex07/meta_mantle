import '../core/metadata_renderer.dart';
import '../models/metadata.dart';
import 'head_adapter_contract.dart';
import 'head_adapter_stub.dart'
    if (dart.library.js_interop) 'head_adapter_web.dart'
    as platform;

/// Coordinates metadata scopes and controls head adapter updates.
class RuntimeCoordinator {
  RuntimeCoordinator({HeadAdapter? adapter})
    : _adapter = adapter ?? platform.createHeadAdapter();

  /// Shared singleton instance used across the package runtime.
  static RuntimeCoordinator instance = RuntimeCoordinator();
  static const Object _imperativeOwner = 'meta_mantle.imperative';

  final HeadAdapter _adapter;
  final Map<Object, WebMetadata> _scopes = <Object, WebMetadata>{};
  final MetadataRenderer _renderer = const MetadataRenderer();
  MetaMantleConfig _config = const MetaMantleConfig();
  String? _currentUrl;

  WebMetadata? _activeMetadata;
  WebMetadata? _previousMetadata;
  int _generationToken = 0;

  MetaMantleConfig get config => _config;
  bool get isSupported => _adapter.isSupported;

  /// The currently active page metadata, or null if no scope is active.
  WebMetadata? get activeMetadata => _activeMetadata;

  /// The previously active page metadata before the last switch or removal.
  WebMetadata? get previousMetadata => _previousMetadata;

  /// Monotonically increasing token incremented on every metadata application.
  int get generationToken => _generationToken;

  /// Read-only snapshot of all registered scopes in insertion order.
  Map<Object, WebMetadata> get scopes => Map.unmodifiable(_scopes);

  void initialize(WebHeadConfig config) {
    _config = config;
    _render();
  }

  void setCurrentUrl(String? url) {
    _currentUrl = url;
    _render();
  }

  /// Activates a metadata [owner] and makes its metadata active.
  void activate(Object owner, WebMetadata metadata) {
    _previousMetadata = _activeMetadata;
    // Reinsert to make an explicitly activated scope the active (last) one.
    _scopes.remove(owner);
    _scopes[owner] = metadata;
    _render();
  }

  /// Updates an existing metadata owner's definition in-place.
  ///
  /// If [owner] is not registered, it is activated.
  /// If [owner] is registered but not active, its definition is updated without
  /// stealing focus from the active scope.
  void update(Object owner, WebMetadata metadata) {
    if (!_scopes.containsKey(owner)) {
      activate(owner, metadata);
      return;
    }
    _scopes[owner] = metadata;
    if (_scopes.keys.last == owner) {
      _render();
    }
  }

  /// Removes [owner] and restores the previously active scope.
  void remove(Object owner) {
    if (_scopes.containsKey(owner)) {
      _previousMetadata = _activeMetadata;
      _scopes.remove(owner);
      _render();
    }
  }

  /// Imperatively updates the title of the active metadata scope.
  void setTitle(String title) {
    final current =
        _scopes[_imperativeOwner] ??
        _scopes.values.lastOrNull ??
        const WebMetadata();
    activate(_imperativeOwner, current.copyWith(title: title));
  }

  /// Imperatively updates the description of the active metadata scope.
  void setDescription(String description) {
    final current =
        _scopes[_imperativeOwner] ??
        _scopes.values.lastOrNull ??
        const WebMetadata();
    activate(_imperativeOwner, current.copyWith(description: description));
  }

  /// Imperatively updates the canonical URL of the active metadata scope.
  void setCanonical(String canonical) {
    final current =
        _scopes[_imperativeOwner] ??
        _scopes.values.lastOrNull ??
        const WebMetadata();
    activate(_imperativeOwner, current.copyWith(canonical: canonical));
  }

  /// Clears all package-managed scopes and restores the document head.
  void clear() {
    _previousMetadata = _activeMetadata;
    _scopes.clear();
    _activeMetadata = null;
    _generationToken++;
    _adapter.clear();
  }

  /// Signals that the client application has rendered its initial frame,
  /// smoothly transitioning away the static HTML pre-rendered snapshot.
  void markReady() {
    _adapter.markReady();
  }

  void _render() {
    _generationToken++;
    if (!_adapter.isSupported) {
      _activeMetadata = _scopes.isEmpty ? null : _scopes.values.last;
      return;
    }
    if (_scopes.isEmpty) {
      _activeMetadata = null;
      _adapter.clear();
      return;
    }
    final active = _scopes.values.last;
    _activeMetadata = active;
    final tags = _renderer.render(
      active,
      config: _config,
      currentUrl: _currentUrl,
    );
    _adapter.apply(tags);
  }
}
