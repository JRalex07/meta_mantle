/// Defines the rendering strategy for MetaMantle web applications.
///
/// Rendering strategies dictate how content is displayed and interacted with in the browser,
/// and are completely independent from [BuildMode] (which defines static generation vs metadata injection).
enum RenderingStrategy {
  /// Strategy A: Flutter Canvas
  ///
  /// Standard Flutter Web rendering using full-page CanvasKit, Skwasm, or HTML canvas.
  /// Used when an application requires Flutter's full widget rendering, animation, and gesture model.
  /// DevTools inspection shows Flutter's canvas/glass-pane surface.
  flutterCanvas,

  /// Strategy B: Semantic DOM
  ///
  /// The application is rendered as native browser HTML elements (`<h1>`, `<p>`, `<nav>`, `<a>`, `<button>`, etc.).
  /// Real HTML DOM nodes with zero full-page Flutter canvas overlay.
  /// DevTools element selector directly inspects semantic HTML elements.
  semanticDom,

  /// Strategy C: DOM with Flutter Islands
  ///
  /// Hybrid architecture where the majority of the page is native semantic HTML,
  /// and Flutter is mounted strictly inside designated host container elements (e.g. `<div id="flutter-cart-island">`).
  /// The Flutter engine and canvas are scoped to the host, while surrounding HTML remains
  /// fully accessible, selectable, and inspectable in DevTools.
  domWithFlutterIslands;

  /// Identifier for CLI flags, JSON configuration, and HTML attributes.
  String get id {
    switch (this) {
      case RenderingStrategy.flutterCanvas:
        return 'flutter-canvas';
      case RenderingStrategy.semanticDom:
        return 'semantic-dom';
      case RenderingStrategy.domWithFlutterIslands:
        return 'dom-with-flutter-islands';
    }
  }

  /// Parses a string into a [RenderingStrategy], defaulting to [flutterCanvas].
  static RenderingStrategy fromString(String? name) {
    if (name == null) return RenderingStrategy.flutterCanvas;
    final normalized = name
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '');
    switch (normalized) {
      case 'fluttercanvas':
      case 'flutter':
      case 'canvas':
        return RenderingStrategy.flutterCanvas;
      case 'semanticdom':
      case 'semantic':
      case 'dom':
      case 'html':
        return RenderingStrategy.semanticDom;
      case 'domwithflutterislands':
      case 'flutterislands':
      case 'islands':
      case 'island':
      case 'hybridislands':
        return RenderingStrategy.domWithFlutterIslands;
      default:
        return RenderingStrategy.flutterCanvas;
    }
  }

  /// Whether this strategy uses Flutter's full-page canvas.
  bool get isFlutterCanvas => this == RenderingStrategy.flutterCanvas;

  /// Whether this strategy uses pure semantic DOM nodes.
  bool get isSemanticDom => this == RenderingStrategy.semanticDom;

  /// Whether this strategy mounts Flutter inside designated island containers.
  bool get isDomWithFlutterIslands =>
      this == RenderingStrategy.domWithFlutterIslands;
}
