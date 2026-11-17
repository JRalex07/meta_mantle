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
  function findIsland() {
    return document.querySelector('.mantle-flutter-island') ||
           document.querySelector('[data-mantle-island]') ||
           document.getElementById('flutter-cart-island') ||
           document.getElementById('flutter-island');
  }

  function setupIsland() {
    var island = findIsland();
    if (!island) return;

    if (window._flutter && window._flutter.loader) {
      var origLoad = window._flutter.loader.load;
      window._flutter.loader.load = function(options) {
        options = options || {};
        var userOnEntrypoint = options.onEntrypointLoaded;
        options.onEntrypointLoaded = async function(engineInitializer) {
          var targetHost = findIsland();
          if (targetHost) {
            var appRunner = await engineInitializer.initializeEngine({
              hostElement: targetHost
            });
            await appRunner.runApp();
            document.documentElement.setAttribute('data-mantle-runtime', 'ready');
            window.__mantleRuntimeReady = true;
            targetHost.setAttribute('data-mantle-island-mounted', 'true');
          } else {
            var appRunner = await engineInitializer.initializeEngine();
            await appRunner.runApp();
          }
          if (typeof userOnEntrypoint === 'function') {
            userOnEntrypoint(engineInitializer);
          }
        };
        return origLoad.call(window._flutter.loader, options);
      };
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupIsland);
  } else {
    setupIsland();
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
      return '<main id="app" class="mantle-dom-root" role="main">\n$htmlContent\n</main>';
    }
    if (renderingStrategy == RenderingStrategy.domWithFlutterIslands) {
      return '<main id="app" class="mantle-island-page" role="main">\n$htmlContent\n</main>';
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
