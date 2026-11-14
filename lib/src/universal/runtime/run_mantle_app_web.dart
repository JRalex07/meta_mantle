import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../rendering/dom_renderer_web.dart';
import '../routing/mantle_route.dart';

/// Launches a [MantleApp] directly into the browser DOM (Mode B).
/// Produces actual semantic HTML and attaches event listeners with zero Flutter CanvasKit/Skwasm overhead.
void runMantleApp(MantleApp app, {bool hydrate = true}) {
  final container = web.document.getElementById('app') ?? web.document.body;
  if (container == null) return;

  var currentPath = web.window.location.pathname;
  if (currentPath.isEmpty) currentPath = app.initialPath;

  late MantleNavigationContext navContext;
  final domRenderer = const MantleDomRenderer();
  final hydrator = const MantleHydrator();

  void renderCurrentRoute({bool allowHydration = false}) {
    final match = app.router.match(currentPath);
    if (match == null) {
      container.textContent = '404 - Page Not Found';
      return;
    }

    final component = match.build(navContext);
    final mantleNode = component.toNode(navContext);

    // If server-rendered markup exists and hydration is requested, hydrate instead of full replace
    if (allowHydration && container.children.length > 0) {
      final firstChild = container.firstElementChild;
      if (firstChild != null) {
        hydrator.hydrate(firstChild, mantleNode);
        return;
      }
    }

    domRenderer.mount(mantleNode, container);
  }

  navContext = MantleNavigationContext(
    currentPath: currentPath,
    onGo: (path, {Map<String, String>? queryParameters}) {
      currentPath = path;
      var fullUrl = path;
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final query = queryParameters.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');
        fullUrl = '$path?$query';
      }
      web.window.history.pushState(null, '', fullUrl);
      renderCurrentRoute(allowHydration: false);
    },
    onBack: () {
      web.window.history.back();
    },
  );

  // Listen to browser navigation (back/forward)
  web.window.addEventListener(
    'popstate',
    ((web.Event e) {
      currentPath = web.window.location.pathname;
      renderCurrentRoute(allowHydration: false);
    }).toJS,
  );

  // Initial render or hydration
  renderCurrentRoute(allowHydration: hydrate);

  // Transition away static HTML pre-render snapshot once client DOM is mounted
  final prerenderRoot = web.document.getElementById('mantle-prerender-root');
  if (prerenderRoot != null) {
    prerenderRoot.setAttribute('aria-hidden', 'true');
    prerenderRoot.classList.add('mantle-fade-out');
    web.window.setTimeout(
      (() {
        prerenderRoot.remove();
      }).toJS,
      250.toJS,
    );
  }
}
