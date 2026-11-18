import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import '../../core/metadata_renderer.dart';
import '../../models/metadata.dart';
import '../../models/rendering_strategy.dart';
import '../models/build_web_options.dart';

/// Integrates MetaMantle static rendering with Flutter's web bootstrap pipeline.
class BootstrapAdapter {
  const BootstrapAdapter();

  /// Inspects the project for an existing custom `web/flutter_bootstrap.js` template.
  Future<File?> findCustomBootstrapTemplate(Directory projectDir) async {
    final file = File(
      '${projectDir.path}${Platform.pathSeparator}web${Platform.pathSeparator}flutter_bootstrap.js',
    );
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Verifies that a bootstrap file contains required Flutter template tokens if applicable.
  bool isValidBootstrapTemplate(String content) {
    if (content.contains('{{flutter_js}}') &&
        content.contains('{{flutter_build_config}}')) {
      return true;
    }
    // Alternatively, modern compiled bootstrap contains _flutter.loader.load or engineInitializer
    return content.contains('_flutter.loader.load') ||
        content.contains('load({') ||
        content.contains('flutter_bootstrap.js');
  }

  /// Generates the client startup coordination script for Mode C ([BuildMode.hybrid]).
  /// Coordinated snapshot removal occurs strictly when the application signals readiness
  /// via [window.__mantleClientReady] (or [MetaMantle.markReady()]), without arbitrary timeouts.
  /// Also protects the static snapshot if an unhandled runtime error occurs before ready.
  String generateClientHandshakeScript() {
    return '''
<script id="mantle-startup-bridge">
(function() {
  var isReady = false;
  window.__mantleClientReady = function() {
    if (isReady) return;
    isReady = true;
    document.documentElement.setAttribute('data-mantle-runtime', 'ready');
    window.__mantleRuntimeReady = true;
    var root = document.getElementById('mantle-prerender-root');
    if (root) {
      root.setAttribute('aria-hidden', 'true');
      root.classList.add('mantle-fade-out');
      // If focus is currently inside the prerender root, blur to avoid invisible focus trapping
      if (document.activeElement && root.contains(document.activeElement)) {
        document.activeElement.blur();
      }
      setTimeout(function() {
        if (root && root.parentNode) {
          root.parentNode.removeChild(root);
        }
      }, 250);
    }
  };

  // Preserve useful static content if client runtime crashes before reporting ready
  window.addEventListener('error', function(e) {
    if (!isReady) {
      console.warn('[MetaMantle] Client runtime error detected prior to readiness. Retaining static snapshot.', e.error || e.message);
    }
  });
})();
</script>
''';
  }

  /// Generates the scoped island startup script for Strategy C ([RenderingStrategy.domWithFlutterIslands]).
  /// Scopes Flutter engine and canvas mounting strictly inside designated island container(s).
  String generateIslandBootstrapScript() {
    return '''
<script id="mantle-island-initializer">
(function() {
  function getIslands() {
    return Array.from(document.querySelectorAll('.mantle-flutter-island, [data-mantle-island]'));
  }

  var activeViews = [];
  var flutterApp = null;

  // Signal from Dart notifying that a specific multi-view island has rendered and is ready
  window.__mantleSignalViewReady = function(viewId) {
    for (var i = 0; i < activeViews.length; i++) {
      if (activeViews[i].viewId === viewId) {
        var isl = activeViews[i].island;
        isl.setAttribute('data-mantle-island-lifecycle', 'mounted');
        isl.setAttribute('data-mantle-island-mounted', 'true');

        // Hide static fallback content now that real Flutter view is mounted
        var fallback = isl.querySelector('.mantle-row, .mantle-island-fallback');
        if (fallback) {
          fallback.style.display = 'none';
        }

        var name = activeViews[i].name;
        var mountEvent = new CustomEvent('mantle:island-mounted', {
          bubbles: true,
          detail: { id: isl.id, name: name, viewId: viewId }
        });
        isl.dispatchEvent(mountEvent);
        window.dispatchEvent(mountEvent);
        break;
      }
    }

    var allMounted = activeViews.length > 0 && activeViews.every(function(v) {
      return v.island.getAttribute('data-mantle-island-lifecycle') === 'mounted';
    });
    if (allMounted) {
      document.documentElement.setAttribute('data-mantle-runtime', 'ready');
      window.__mantleRuntimeReady = true;
    }
  };

  function hookLoader(loader) {
    if (!loader || loader.__mantleHooked) return;
    loader.__mantleHooked = true;
    var origLoad = loader.load;
    loader.load = function(options) {
      options = options || {};
      var userOnEntrypoint = options.onEntrypointLoaded;
      options.onEntrypointLoaded = async function(engineInitializer) {
        var islands = getIslands();
        if (!islands.length) {
          if (typeof userOnEntrypoint === 'function') {
            userOnEntrypoint(engineInitializer);
          }
          return;
        }

        // Transition islands to initializing state
        for (var i = 0; i < islands.length; i++) {
          islands[i].setAttribute('data-mantle-island-lifecycle', 'initializing');
        }

        try {
          // Initialize Flutter Engine in multi-view mode per supported SDK API.
          // In multi-view mode, hostElement is NOT passed to initializeEngine().
          var appRunner = await engineInitializer.initializeEngine({
            multiViewEnabled: true
          });
          flutterApp = await appRunner.runApp();
          window.__mantleFlutterApp = flutterApp;
          window.__mantleActiveViews = window.__mantleActiveViews || {};

          // Attach each island host element using app.addView({ hostElement })
          for (var j = 0; j < islands.length; j++) {
            var isl = islands[j];
            var name = isl.getAttribute('data-mantle-island') || (isl.id.indexOf('cart') !== -1 ? 'cart' : 'counter');
            try {
              var viewId = flutterApp.addView({ hostElement: isl });
              if (typeof viewId === 'number' && viewId >= 0) {
                activeViews.push({ island: isl, viewId: viewId, name: name });
                window.__mantleActiveViews[viewId] = name;
                isl.setAttribute('data-mantle-view-id', String(viewId));
                // Island remains in 'initializing' until Dart signals view readiness
              } else {
                isl.setAttribute('data-mantle-island-lifecycle', 'error');
              }
            } catch (addErr) {
              console.error('[MetaMantle] addView failed for island #' + isl.id, addErr);
              isl.setAttribute('data-mantle-island-lifecycle', 'error');
            }
          }

          if (typeof userOnEntrypoint === 'function') {
            userOnEntrypoint(engineInitializer);
          }
        } catch (engineErr) {
          console.error('[MetaMantle] Multi-view engine initialization failed:', engineErr);
          for (var k = 0; k < islands.length; k++) {
            islands[k].setAttribute('data-mantle-island-lifecycle', 'error');
          }
        }
      };
      return origLoad.call(loader, options);
    };
  }

  function setupIslands() {
    var islands = getIslands();
    if (!islands.length) return;

    // Set initial uninitialized lifecycle state on each island host
    for (var i = 0; i < islands.length; i++) {
      var isl = islands[i];
      isl.setAttribute('data-mantle-island-lifecycle', 'uninitialized');
      isl.removeAttribute('data-mantle-island-mounted');
      isl.removeAttribute('data-mantle-view-id');
      isl.removeAttribute('data-mantle-dart-callback-executed');
    }

    window._flutter = window._flutter || {};
    var currentLoader = window._flutter.loader;
    if (currentLoader && currentLoader.load) {
      hookLoader(currentLoader);
    }
    try {
      Object.defineProperty(window._flutter, 'loader', {
        configurable: true,
        enumerable: true,
        get: function() { return currentLoader; },
        set: function(val) {
          currentLoader = val;
          if (currentLoader && currentLoader.load) {
            hookLoader(currentLoader);
          }
        }
      });
    } catch (e) {}

    var pollCount = 0;
    var checkInterval = setInterval(function() {
      pollCount++;
      if (window._flutter && window._flutter.loader && !window._flutter.loader.__mantleHooked) {
        hookLoader(window._flutter.loader);
      }
      if (pollCount > 100 || (window._flutter && window._flutter.loader && window._flutter.loader.__mantleHooked)) {
        clearInterval(checkInterval);
      }
    }, 20);
  }

  window.__mantleDisposeIslands = function() {
    var islands = getIslands();
    for (var i = 0; i < islands.length; i++) {
      islands[i].setAttribute('data-mantle-island-lifecycle', 'disposing');
    }

    // Call supported removeView(viewId) for each active view to let Flutter clean up
    if (flutterApp && typeof flutterApp.removeView === 'function') {
      for (var j = 0; j < activeViews.length; j++) {
        try {
          flutterApp.removeView(activeViews[j].viewId);
        } catch (e) {
          console.warn('[MetaMantle] Failed to remove view ' + activeViews[j].viewId, e);
        }
      }
    }
    activeViews = [];
    window.__mantleActiveViews = {};

    for (var k = 0; k < islands.length; k++) {
      var isl = islands[k];
      isl.setAttribute('data-mantle-island-lifecycle', 'disposed');
      isl.removeAttribute('data-mantle-island-mounted');
      isl.removeAttribute('data-mantle-view-id');
      isl.removeAttribute('data-mantle-dart-callback-executed');

      // Restore static fallback visibility
      var fallback = isl.querySelector('.mantle-row, .mantle-island-fallback');
      if (fallback) {
        fallback.style.display = '';
      }

      var dispEvent = new CustomEvent('mantle:island-disposed', {
        bubbles: true,
        detail: { id: isl.id }
      });
      isl.dispatchEvent(dispEvent);
      window.dispatchEvent(dispEvent);
    }
  };

  window.__mantleRemountIslands = function() {
    if (typeof window.__mantleDisposeIslands === 'function') {
      window.__mantleDisposeIslands();
    }
    if (!flutterApp || typeof flutterApp.addView !== 'function') {
      return Promise.reject(new Error('Flutter application not initialized'));
    }

    var islands = getIslands();
    for (var i = 0; i < islands.length; i++) {
      var isl = islands[i];
      isl.setAttribute('data-mantle-island-lifecycle', 'initializing');
      var name = isl.getAttribute('data-mantle-island') || (isl.id.indexOf('cart') !== -1 ? 'cart' : 'counter');
      try {
        var viewId = flutterApp.addView({ hostElement: isl });
        if (typeof viewId === 'number' && viewId >= 0) {
          activeViews.push({ island: isl, viewId: viewId, name: name });
          window.__mantleActiveViews[viewId] = name;
          isl.setAttribute('data-mantle-view-id', String(viewId));
        } else {
          isl.setAttribute('data-mantle-island-lifecycle', 'error');
        }
      } catch (err) {
        console.error('[MetaMantle] Remount addView failed for island #' + isl.id, err);
        isl.setAttribute('data-mantle-island-lifecycle', 'error');
      }
    }
    return Promise.resolve();
  };

  window.addEventListener('beforeunload', function() {
    if (typeof window.__mantleDisposeIslands === 'function') {
      window.__mantleDisposeIslands();
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupIslands);
  } else {
    setupIslands();
  }
})();
</script>
''';
  }

  /// Generates client interaction bridge script for Strategy B ([RenderingStrategy.semanticDom]).
  String generateSemanticDomClientScript() {
    return '''
<script id="mantle-dom-client">
(function() {
  document.documentElement.setAttribute('data-mantle-runtime', 'ready');
  window.__mantleRuntimeReady = true;

  // Real browser DOM interaction bridge
  document.addEventListener('click', function(e) {
    var target = e.target;
    var anchor = target.closest ? target.closest('a') : null;
    if (anchor && anchor.getAttribute('href') && !anchor.getAttribute('target') && !anchor.getAttribute('download')) {
      var href = anchor.getAttribute('href');
      if (href.startsWith('/') && !href.startsWith('//')) {
        // Safe internal deep link
      }
    }
  });
})();
</script>
''';
  }

  /// Injects prerender CSS styles into the document head.
  String generatePrerenderStyles() {
    return '''
<style id="mantle-prerender-style">
  body {
    margin: 0;
    padding: 0;
  }
  #mantle-prerender-root {
    position: relative;
    z-index: 1;
    background-color: transparent;
  }
  #mantle-prerender-root[aria-hidden="true"] {
    pointer-events: none;
  }
  .mantle-fade-out {
    opacity: 0;
    transition: opacity 0.25s ease-out;
    pointer-events: none;
  }
</style>
''';
  }

  /// Wraps generated semantic HTML content in the standard prerender root container.
  String wrapPrerenderContent(
    String htmlContent, {
    required BuildMode mode,
    RenderingStrategy renderingStrategy = RenderingStrategy.flutterCanvas,
  }) {
    if (mode == BuildMode.metadata) {
      return '';
    }
    if (renderingStrategy == RenderingStrategy.semanticDom) {
      if (htmlContent.trimLeft().startsWith('<main')) {
        return htmlContent
            .replaceFirst(RegExp(r'<main\b'), '<main id="app" role="main"')
            .replaceFirst(RegExp(r'class="'), 'class="mantle-dom-root ');
      }
      return '<main id="app" class="mantle-dom-root" role="main">\n$htmlContent\n</main>';
    }
    if (renderingStrategy == RenderingStrategy.domWithFlutterIslands) {
      if (htmlContent.trimLeft().startsWith('<main')) {
        return htmlContent
            .replaceFirst(RegExp(r'<main\b'), '<main id="app"')
            .replaceFirst(RegExp(r'class="'), 'class="mantle-island-page ');
      }
      return '<main id="app" class="mantle-island-page">\n$htmlContent\n</main>';
    }
    return '<div id="mantle-prerender-root" class="mantle-prerendered" role="region" aria-label="Pre-rendered Content">\n$htmlContent\n</div>';
  }

  /// Synthesizes complete prerender HTML by injecting head metadata, prerender CSS,
  /// semantic content container, and client coordination scripts into [templateHtml].
  String buildPrerenderBootstrapHtml({
    required String templateHtml,
    required WebMetadata metadata,
    required String semanticHtml,
    required BuildMode mode,
    RenderingStrategy renderingStrategy = RenderingStrategy.flutterCanvas,
    String baseHref = '/',
    MetadataRenderer metadataRenderer = const MetadataRenderer(),
    MetaMantleConfig config = const MetaMantleConfig(),
  }) {
    final tags = metadataRenderer.render(metadata, config: config);
    final document = html_parser.parse(templateHtml);
    final head = document.querySelector('head');
    final body = document.querySelector('body');
    final htmlEl = document.querySelector('html');

    if (htmlEl != null) {
      htmlEl.attributes['data-mantle-strategy'] = renderingStrategy.id;
      if (renderingStrategy == RenderingStrategy.semanticDom) {
        htmlEl.attributes['data-mantle-runtime'] = 'ready';
      }
    }

    if (head != null) {
      for (final tag in tags) {
        if (tag.tagName == 'title') {
          final existing = head.querySelector('title');
          if (existing != null) {
            existing.text = tag.textContent ?? '';
          } else {
            final t = document.createElement('title')
              ..text = tag.textContent ?? '';
            head.append(t);
          }
          continue;
        }

        final el = document.createElement(tag.tagName);
        for (final attr in tag.attributes.entries) {
          el.attributes[attr.key] = attr.value;
        }
        if (tag.textContent != null) {
          el.text = tag.textContent!;
        }
        head.append(el);
      }

      if (mode != BuildMode.metadata &&
          renderingStrategy != RenderingStrategy.semanticDom) {
        final existingStyle = head.querySelector('#mantle-prerender-style');
        if (existingStyle != null) {
          existingStyle.remove();
        }
        final styleEl = html_parser.parseFragment(generatePrerenderStyles());
        head.append(styleEl);
      }
    }

    if (body != null && mode != BuildMode.metadata && semanticHtml.isNotEmpty) {
      final existingRoot = body.querySelector('#mantle-prerender-root');
      if (existingRoot != null) {
        existingRoot.remove();
      }
      final existingApp = body.querySelector('#app');
      if (existingApp != null) {
        existingApp.remove();
      }
      final existingBridge = body.querySelector('#mantle-startup-bridge');
      if (existingBridge != null) {
        existingBridge.remove();
      }
      final existingIsland = body.querySelector('#mantle-island-initializer');
      if (existingIsland != null) {
        existingIsland.remove();
      }
      final existingDomClient = body.querySelector('#mantle-dom-client');
      if (existingDomClient != null) {
        existingDomClient.remove();
      }

      final wrapped = wrapPrerenderContent(
        semanticHtml,
        mode: mode,
        renderingStrategy: renderingStrategy,
      );
      final contentFragment = html_parser.parseFragment(wrapped);
      if (contentFragment.children.isNotEmpty) {
        body.children.insert(0, contentFragment.children.first);
      }

      if (renderingStrategy == RenderingStrategy.semanticDom) {
        // Strip full-page Flutter bootstrap script so Flutter Canvas never takes over the document
        final scriptsToRemove =
            [
                  ...body.querySelectorAll('script'),
                  if (head != null) ...head.querySelectorAll('script'),
                ]
                .where(
                  (s) =>
                      s.attributes['src']?.contains('flutter_bootstrap.js') ??
                      false,
                )
                .toList();
        for (final s in scriptsToRemove) {
          s.remove();
        }

        final domClientFragment = html_parser.parseFragment(
          generateSemanticDomClientScript(),
        );
        body.append(domClientFragment);
      } else if (renderingStrategy == RenderingStrategy.domWithFlutterIslands) {
        final islandInitFragment = html_parser.parseFragment(
          generateIslandBootstrapScript(),
        );
        body.children.insert(0, islandInitFragment.children.first);
      } else if (mode == BuildMode.hybrid) {
        final bridgeFragment = html_parser.parseFragment(
          generateClientHandshakeScript(),
        );
        body.append(bridgeFragment);
      }
    }

    return document.outerHtml;
  }
}
