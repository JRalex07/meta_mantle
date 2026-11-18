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
  var expectedIslandElements = [];
  var flutterApp = null;

  // Signal from Dart notifying that a specific multi-view island has rendered and is ready
  window.__mantleSignalViewReady = function(viewId) {
    if (typeof viewId !== 'number' || viewId < 0) {
      console.warn('[MetaMantle] Invalid viewId signaled:', viewId);
      return;
    }

    var targetView = null;
    for (var i = 0; i < activeViews.length; i++) {
      if (activeViews[i].viewId === viewId) {
        targetView = activeViews[i];
        break;
      }
    }

    if (!targetView) {
      console.warn('[MetaMantle] No active view registered for viewId:', viewId);
      return;
    }

    var isl = targetView.island;
    isl.setAttribute('data-mantle-island-lifecycle', 'mounted');
    isl.setAttribute('data-mantle-island-mounted', 'true');

    // Hide static fallback content now that real Flutter view is mounted
    var fallback = isl.querySelector('.mantle-row, .mantle-island-fallback');
    if (fallback) {
      fallback.style.display = 'none';
    }

    var mountEvent = new CustomEvent('mantle:island-mounted', {
      bubbles: true,
      detail: { id: isl.id, name: targetView.name, viewId: viewId }
    });
    isl.dispatchEvent(mountEvent);
    window.dispatchEvent(mountEvent);

    checkGlobalReadiness();
  };

  function checkGlobalReadiness() {
    if (!expectedIslandElements || expectedIslandElements.length === 0) {
      return;
    }

    var totalExpected = expectedIslandElements.length;
    var mountedCount = 0;
    var errorCount = 0;

    for (var i = 0; i < totalExpected; i++) {
      var state = expectedIslandElements[i].getAttribute('data-mantle-island-lifecycle');
      if (state === 'mounted') {
        mountedCount++;
      } else if (state === 'error') {
        errorCount++;
      }
    }

    if (mountedCount === totalExpected && totalExpected > 0) {
      document.documentElement.setAttribute('data-mantle-runtime', 'ready');
      document.documentElement.setAttribute('data-mantle-islands-ready', 'true');
      window.__mantleRuntimeReady = true;
    } else if (errorCount > 0) {
      // If any expected island encountered an error, runtime readiness MUST NOT be reported as ready.
      document.documentElement.setAttribute('data-mantle-runtime', 'error');
      document.documentElement.setAttribute('data-mantle-islands-ready', 'false');
      window.__mantleRuntimeReady = false;
    } else {
      document.documentElement.removeAttribute('data-mantle-runtime');
      document.documentElement.setAttribute('data-mantle-islands-ready', 'false');
      window.__mantleRuntimeReady = false;
    }
  }

  async function attachExpectedIslands(app) {
    if (!app || typeof app.addView !== 'function') {
      throw new Error('[MetaMantle] Invalid Flutter application instance: missing addView()');
    }
    flutterApp = app;
    window.__mantleFlutterApp = flutterApp;
    window.__mantleActiveViews = window.__mantleActiveViews || {};

    for (var j = 0; j < expectedIslandElements.length; j++) {
      var isl = expectedIslandElements[j];
      // Prevent duplicate views if already attached for this island
      var alreadyAttached = false;
      for (var a = 0; a < activeViews.length; a++) {
        if (activeViews[a].island === isl) {
          alreadyAttached = true;
          break;
        }
      }
      if (alreadyAttached) {
        continue;
      }

      if (!isl.__mantleFallbackHtml) {
        isl.__mantleFallbackHtml = isl.innerHTML;
      }
      var name = isl.getAttribute('data-mantle-island') || (isl.id.indexOf('cart') !== -1 ? 'cart' : 'counter');
      try {
        var viewId = app.addView({ hostElement: isl });
        if (typeof viewId === 'number' && viewId >= 0) {
          activeViews.push({ island: isl, viewId: viewId, name: name });
          window.__mantleActiveViews[viewId] = name;
          isl.setAttribute('data-mantle-view-id', String(viewId));
          // Island remains in 'initializing' until Dart signals view readiness
        } else {
          console.error('[MetaMantle] addView returned invalid view ID for island #' + isl.id, viewId);
          isl.setAttribute('data-mantle-island-lifecycle', 'error');
          if (isl.__mantleFallbackHtml) isl.innerHTML = isl.__mantleFallbackHtml;
        }
      } catch (addErr) {
        console.error('[MetaMantle] addView threw for island #' + isl.id, addErr);
        isl.setAttribute('data-mantle-island-lifecycle', 'error');
        if (isl.__mantleFallbackHtml) isl.innerHTML = isl.__mantleFallbackHtml;
      }
    }
    checkGlobalReadiness();
  }

  function createWrappedEngineInitializer(realInitializer, options) {
    if (!realInitializer || typeof realInitializer.initializeEngine !== 'function') {
      throw new Error('[MetaMantle] Invalid engineInitializer: missing initializeEngine()');
    }

    var rawConfig = options ? options.config : null;
    var initPromise = null;
    var runAppPromise = null;
    var activeConfig = null;

    return {
      _realInitializer: realInitializer,
      get initPromise() { return initPromise; },
      get runAppPromise() { return runAppPromise; },
      initializeEngine: function(consumerConfig) {
        if (initPromise) {
          if (consumerConfig && activeConfig) {
            var differs = false;
            var keys = Object.keys(consumerConfig);
            for (var k = 0; k < keys.length; k++) {
              if (activeConfig[keys[k]] !== consumerConfig[keys[k]]) {
                differs = true;
                break;
              }
            }
            if (differs) {
              console.warn('[MetaMantle] initializeEngine() already in-flight or initialized with initial configuration. Subsequent differing configuration is ignored to preserve single engine identity.');
            }
          }
          return initPromise;
        }

        var merged = Object.assign({}, rawConfig || {}, consumerConfig || {}, {
          multiViewEnabled: true
        });
        activeConfig = merged;

        initPromise = Promise.resolve().then(function() {
          return realInitializer.initializeEngine(merged);
        }).then(function(realAppRunner) {
          if (!realAppRunner || typeof realAppRunner.runApp !== 'function') {
            throw new Error('[MetaMantle] Invalid appRunner from initializeEngine(): missing runApp()');
          }
          return {
            _realAppRunner: realAppRunner,
            runApp: function(runAppOptions) {
              if (runAppPromise) {
                return runAppPromise;
              }

              runAppPromise = Promise.resolve().then(function() {
                return realAppRunner.runApp(runAppOptions);
              }).then(async function(app) {
                flutterApp = app;
                window.__mantleFlutterApp = flutterApp;
                await attachExpectedIslands(app);
                return app;
              }).catch(function(err) {
                runAppPromise = null;
                throw err;
              });

              return runAppPromise;
            }
          };
        }).catch(function(err) {
          initPromise = null;
          activeConfig = null;
          throw err;
        });

        return initPromise;
      }
    };
  }

  window.__mantleCreateWrappedEngineInitializer = createWrappedEngineInitializer;

  function hookLoader(loader) {
    if (!loader || loader.__mantleHooked) return;
    loader.__mantleHooked = true;
    var origLoad = loader.load;
    loader.load = function(options) {
      options = options || {};
      var userOnEntrypoint = options.onEntrypointLoaded;

      options.onEntrypointLoaded = async function(engineInitializer) {
        expectedIslandElements = getIslands();
        if (!expectedIslandElements.length) {
          if (typeof userOnEntrypoint === 'function') {
            return await userOnEntrypoint(engineInitializer);
          }
          var defaultRunner = await engineInitializer.initializeEngine(options.config);
          return await defaultRunner.runApp();
        }

        // Transition islands to initializing state
        for (var i = 0; i < expectedIslandElements.length; i++) {
          expectedIslandElements[i].setAttribute('data-mantle-island-lifecycle', 'initializing');
        }

        var wrappedInitializer = createWrappedEngineInitializer(engineInitializer, options);

        try {
          if (typeof userOnEntrypoint === 'function') {
            var cbResult = userOnEntrypoint(wrappedInitializer);
            if (cbResult && typeof cbResult.then === 'function') {
              await cbResult;
            }
          }

          var runner = await wrappedInitializer.initializeEngine();
          return await runner.runApp();
        } catch (engineErr) {
          console.error('[MetaMantle] Island initialization error:', engineErr);
          for (var k = 0; k < expectedIslandElements.length; k++) {
            expectedIslandElements[k].setAttribute('data-mantle-island-lifecycle', 'error');
          }
          checkGlobalReadiness();
          throw engineErr;
        }
      };
      return origLoad.call(loader, options);
    };
  }

  window.__mantleHookLoader = hookLoader;

  function setupIslands() {
    var islands = getIslands();
    if (!islands.length) return;

    expectedIslandElements = islands;

    // Set initial uninitialized lifecycle state on each island host
    for (var i = 0; i < islands.length; i++) {
      var isl = islands[i];
      if (!isl.__mantleFallbackHtml) {
        isl.__mantleFallbackHtml = isl.innerHTML;
      }
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
    var hasDisposalError = false;

    // Transition all currently non-disposed islands into 'disposing'
    for (var i = 0; i < islands.length; i++) {
      var curState = islands[i].getAttribute('data-mantle-island-lifecycle');
      if (curState !== 'disposed') {
        islands[i].setAttribute('data-mantle-island-lifecycle', 'disposing');
      }
    }

    var currentApp = (window.__mantleFlutterApp !== undefined && window.__mantleFlutterApp !== null)
      ? window.__mantleFlutterApp
      : (window.__mantleFlutterApp === null ? null : flutterApp);
    var remainingViews = [];
    var canRemove = currentApp && typeof currentApp.removeView === 'function';

    if (!canRemove) {
      if (activeViews.length > 0) {
        hasDisposalError = true;
        var errorMsg = !currentApp
          ? 'Missing Flutter application instance'
          : 'Flutter application missing callable removeView()';
        console.warn('[MetaMantle] View removal impossible: ' + errorMsg);
        for (var m = 0; m < activeViews.length; m++) {
          remainingViews.push(activeViews[m]);
          var errIsl = activeViews[m].island;
          if (errIsl) {
            errIsl.setAttribute('data-mantle-island-lifecycle', 'error');
            errIsl.setAttribute('data-mantle-disposal-error', errorMsg);
          }
        }
      }
    } else {
      for (var j = 0; j < activeViews.length; j++) {
        var entry = activeViews[j];
        if (typeof entry.viewId !== 'number' || entry.viewId < 0) {
          hasDisposalError = true;
          remainingViews.push(entry);
          if (entry.island) {
            entry.island.setAttribute('data-mantle-island-lifecycle', 'error');
            entry.island.setAttribute('data-mantle-disposal-error', 'Invalid view ID: ' + entry.viewId);
          }
          continue;
        }

        try {
          currentApp.removeView(entry.viewId);
          if (window.__mantleActiveViews) {
            delete window.__mantleActiveViews[entry.viewId];
          }
        } catch (e) {
          console.warn('[MetaMantle] removeView error for view ' + entry.viewId, e);
          hasDisposalError = true;
          remainingViews.push(entry);
          if (entry.island) {
            entry.island.setAttribute('data-mantle-island-lifecycle', 'error');
            entry.island.setAttribute('data-mantle-disposal-error', String(e && e.message ? e.message : e));
          }
        }
      }
    }
    activeViews = remainingViews;

    for (var k = 0; k < islands.length; k++) {
      var isl = islands[k];
      var hasActiveView = false;
      for (var r = 0; r < activeViews.length; r++) {
        if (activeViews[r].island === isl) {
          hasActiveView = true;
          break;
        }
      }

      if (hasActiveView) {
        // Island still has an un-removed view. Retain error & diagnostic state; DO NOT restore fallback!
        continue;
      }

      var prevState = isl.getAttribute('data-mantle-island-lifecycle');
      if (prevState === 'disposed') {
        // Idempotent: already cleanly disposed
        continue;
      }

      isl.setAttribute('data-mantle-island-lifecycle', 'disposed');
      isl.removeAttribute('data-mantle-island-mounted');
      isl.removeAttribute('data-mantle-view-id');
      isl.removeAttribute('data-mantle-dart-callback-executed');
      isl.removeAttribute('data-mantle-disposal-error');

      // Restore static fallback content only on successful removal
      if (isl.__mantleFallbackHtml) {
        isl.innerHTML = isl.__mantleFallbackHtml;
      } else {
        var fallback = isl.querySelector('.mantle-row, .mantle-island-fallback');
        if (fallback) {
          fallback.style.display = '';
        }
      }

      var dispEvent = new CustomEvent('mantle:island-disposed', {
        bubbles: true,
        detail: { id: isl.id }
      });
      isl.dispatchEvent(dispEvent);
      window.dispatchEvent(dispEvent);
    }

    if (hasDisposalError || activeViews.length > 0) {
      document.documentElement.setAttribute('data-mantle-runtime', 'error');
      document.documentElement.setAttribute('data-mantle-islands-ready', 'false');
      window.__mantleRuntimeReady = false;
    } else {
      document.documentElement.removeAttribute('data-mantle-runtime');
      document.documentElement.removeAttribute('data-mantle-islands-ready');
      window.__mantleRuntimeReady = false;
    }

    return {
      success: !hasDisposalError && activeViews.length === 0,
      hasDisposalError: hasDisposalError,
      remainingViewsCount: activeViews.length
    };
  };

  window.__mantleRemountIslands = function() {
    if (typeof window.__mantleDisposeIslands === 'function') {
      window.__mantleDisposeIslands();
    }
    var currentApp = (window.__mantleFlutterApp !== undefined && window.__mantleFlutterApp !== null)
      ? window.__mantleFlutterApp
      : (window.__mantleFlutterApp === null ? null : flutterApp);
    if (!currentApp || typeof currentApp.addView !== 'function') {
      return Promise.reject(new Error('Flutter application not initialized'));
    }

    expectedIslandElements = getIslands();
    if (!expectedIslandElements.length) {
      return Promise.resolve();
    }

    document.documentElement.removeAttribute('data-mantle-runtime');
    document.documentElement.removeAttribute('data-mantle-islands-ready');
    window.__mantleRuntimeReady = false;

    for (var i = 0; i < expectedIslandElements.length; i++) {
      var isl = expectedIslandElements[i];
      // Check if island still has an active view from a previous failed disposal
      var alreadyHasView = false;
      for (var v = 0; v < activeViews.length; v++) {
        if (activeViews[v].island === isl) {
          alreadyHasView = true;
          break;
        }
      }
      if (alreadyHasView) {
        console.warn('[MetaMantle] Cannot remount island with active view:', isl.id);
        isl.setAttribute('data-mantle-island-lifecycle', 'error');
        continue;
      }

      // Ensure fallback HTML is present before addView attaches Flutter view
      if (isl.__mantleFallbackHtml) {
        isl.innerHTML = isl.__mantleFallbackHtml;
      }
      isl.setAttribute('data-mantle-island-lifecycle', 'initializing');
      var name = isl.getAttribute('data-mantle-island') || (isl.id.indexOf('cart') !== -1 ? 'cart' : 'counter');
      try {
        var viewId = currentApp.addView({ hostElement: isl });
        if (typeof viewId === 'number' && viewId >= 0) {
          activeViews.push({ island: isl, viewId: viewId, name: name });
          window.__mantleActiveViews[viewId] = name;
          isl.setAttribute('data-mantle-view-id', String(viewId));
        } else {
          isl.setAttribute('data-mantle-island-lifecycle', 'error');
          if (isl.__mantleFallbackHtml) isl.innerHTML = isl.__mantleFallbackHtml;
        }
      } catch (err) {
        console.error('[MetaMantle] Remount addView failed for island #' + isl.id, err);
        isl.setAttribute('data-mantle-island-lifecycle', 'error');
        if (isl.__mantleFallbackHtml) isl.innerHTML = isl.__mantleFallbackHtml;
      }
    }
    checkGlobalReadiness();
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
