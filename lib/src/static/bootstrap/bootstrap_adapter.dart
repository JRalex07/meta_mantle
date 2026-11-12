import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import '../../core/metadata_renderer.dart';
import '../../models/metadata.dart';
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
  String generateClientHandshakeScript() {
    return '''
<script id="mantle-startup-bridge">
(function() {
  window.__mantleClientReady = function() {
    var root = document.getElementById('mantle-prerender-root');
    if (root) {
      root.classList.add('mantle-fade-out');
      setTimeout(function() {
        if (root && root.parentNode) root.parentNode.removeChild(root);
      }, 250);
    }
  };
  // Fallback safety timeout: remove snapshot after 8 seconds if client app stalls
  setTimeout(function() {
    if (window.__mantleClientReady) window.__mantleClientReady();
  }, 8000);
})();
</script>
''';
  }

  /// Injects prerender CSS styles into the document head.
  String generatePrerenderStyles() {
    return '''
<style id="mantle-prerender-style">
  #mantle-prerender-root {
    position: relative;
    z-index: 1;
    background-color: transparent;
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
  String wrapPrerenderContent(String htmlContent, {required BuildMode mode}) {
    if (mode == BuildMode.metadata) {
      return '';
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
    String baseHref = '/',
    MetadataRenderer metadataRenderer = const MetadataRenderer(),
    MetaMantleConfig config = const MetaMantleConfig(),
  }) {
    final tags = metadataRenderer.render(metadata, config: config);
    final document = html_parser.parse(templateHtml);
    final head = document.querySelector('head');
    final body = document.querySelector('body');

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

      if (mode != BuildMode.metadata) {
        final styleEl = html_parser.parseFragment(generatePrerenderStyles());
        head.append(styleEl);
      }
    }

    if (body != null && mode != BuildMode.metadata && semanticHtml.isNotEmpty) {
      final wrapped = wrapPrerenderContent(semanticHtml, mode: mode);
      final contentFragment = html_parser.parseFragment(wrapped);
      if (contentFragment.children.isNotEmpty) {
        body.children.insert(0, contentFragment.children.first);
      }

      if (mode == BuildMode.hybrid) {
        final bridgeFragment =
            html_parser.parseFragment(generateClientHandshakeScript());
        body.append(bridgeFragment);
      }
    }

    return document.outerHtml;
  }
}
