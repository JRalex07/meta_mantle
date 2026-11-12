import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import 'renderer_contract.dart';

/// Browser DOM renderer that generates native HTML DOM elements from a [MantleNode] tree.
/// Operates on the real browser DOM with zero Flutter CanvasKit/Skwasm overhead.
class MantleDomRenderer implements MantleRenderer<web.Node> {
  const MantleDomRenderer();

  @override
  web.Node render(MantleNode node) {
    return node.accept(const _DomVisitor());
  }

  /// Mounts a [MantleNode] tree into the target DOM container element.
  void mount(MantleNode node, web.Element container) {
    container.textContent = '';
    final domNode = render(node);
    container.appendChild(domNode);
  }
}

class _DomVisitor implements MantleNodeVisitor<web.Node> {
  const _DomVisitor();

  @override
  web.Node visitElement(MantleElementNode node) {
    final element = web.document.createElement(node.tag) as web.HTMLElement;

    if (node.id != null) element.id = node.id!;
    for (final cls in node.classes) {
      element.classList.add(cls);
    }

    for (final attr in node.attributes.entries) {
      element.setAttribute(attr.key, attr.value);
    }

    for (final style in node.styles.entries) {
      element.style.setProperty(style.key, style.value);
    }

    // Attach event listeners
    for (final event in node.events.entries) {
      final eventName = event.key;
      final callback = event.value;

      element.addEventListener(
        eventName,
        ((web.Event e) {
          Object? value;
          if (element.tagName.toLowerCase() == 'input') {
            final input = element as web.HTMLInputElement;
            value = input.type == 'checkbox' ? input.checked : input.value;
          } else if (element.tagName.toLowerCase() == 'select') {
            final select = element as web.HTMLSelectElement;
            value = select.value;
          }
          callback(MantleEvent(
            type: eventName,
            value: value,
            targetId: element.id.isNotEmpty ? element.id : null,
          ));
        }).toJS,
      );
    }

    // Recursively append children
    for (final child in node.children) {
      element.appendChild(child.accept(this));
    }

    return element;
  }

  @override
  web.Node visitText(MantleTextNode node) {
    if (node.style != null && node.style!.toCssProperties().isNotEmpty) {
      final span = web.document.createElement(node.tag) as web.HTMLElement;
      for (final style in node.style!.toCssProperties().entries) {
        span.style.setProperty(style.key, style.value);
      }
      span.textContent = node.text;
      return span;
    }
    return web.document.createTextNode(node.text);
  }

  @override
  web.Node visitFragment(MantleFragment node) {
    final fragment = web.document.createDocumentFragment();
    for (final child in node.children) {
      fragment.appendChild(child.accept(this));
    }
    return fragment;
  }
}

/// Hydrates an existing server-rendered HTML DOM tree with event listeners
/// and dynamic state bindings without tearing down and recreating the DOM.
class MantleHydrator {
  const MantleHydrator();

  void hydrate(web.Element rootElement, MantleNode node) {
    _hydrateRecursive(rootElement, node);
  }

  void _hydrateRecursive(web.Element domElement, MantleNode node) {
    if (node is MantleElementNode) {
      // Attach event listeners to this matching DOM element
      for (final event in node.events.entries) {
        final eventName = event.key;
        final callback = event.value;

        domElement.addEventListener(
          eventName,
          ((web.Event e) {
            Object? value;
            if (domElement.tagName.toLowerCase() == 'input') {
              final input = domElement as web.HTMLInputElement;
              value = input.type == 'checkbox' ? input.checked : input.value;
            } else if (domElement.tagName.toLowerCase() == 'select') {
              final select = domElement as web.HTMLSelectElement;
              value = select.value;
            }
            callback(MantleEvent(
              type: eventName,
              value: value,
              targetId: domElement.id.isNotEmpty ? domElement.id : null,
            ));
          }).toJS,
        );
      }

      // Reconcile child element nodes
      var domChild = domElement.firstElementChild;
      for (final childNode in node.children) {
        if (childNode is MantleElementNode && domChild != null) {
          _hydrateRecursive(domChild, childNode);
          domChild = domChild.nextElementSibling;
        }
      }
    }
  }
}
