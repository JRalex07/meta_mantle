import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../ir/mantle_diff.dart';
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

  /// Incrementally updates an existing DOM node using tree diffing without full re-creation.
  void patch(web.Node targetDom, MantleNode oldNode, MantleNode newNode) {
    const diffEngine = MantleDiffEngine();
    final patchPlan = diffEngine.diff(oldNode, newNode);
    if (patchPlan != null) {
      _applyPatch(targetDom, patchPlan);
    }
  }

  void _applyPatch(web.Node targetDom, MantlePatch patch) {
    if (patch is ReplaceNodePatch) {
      final parent = targetDom.parentNode;
      if (parent != null) {
        final newDom = render(patch.newNode);
        parent.replaceChild(newDom, targetDom);
      }
      return;
    }

    if (patch is UpdateTextPatch) {
      targetDom.textContent = patch.newText;
      return;
    }

    if (patch is UpdateElementPatch && targetDom.isA<web.HTMLElement>()) {
      final element = targetDom as web.HTMLElement;

      // Update ID
      if (patch.newId != null) {
        if (patch.newId!.isEmpty) {
          element.removeAttribute('id');
        } else {
          element.id = patch.newId!;
        }
      }

      // Update classes
      for (final cls in patch.classesToRemove) {
        element.classList.remove(cls);
      }
      for (final cls in patch.classesToAdd) {
        element.classList.add(cls);
      }

      // Update attributes
      for (final attr in patch.attributesToRemove) {
        element.removeAttribute(attr);
      }
      for (final attr in patch.attributesToSet.entries) {
        element.setAttribute(attr.key, attr.value);
      }

      // Update styles
      for (final style in patch.stylesToRemove) {
        element.style.removeProperty(style);
      }
      for (final style in patch.stylesToSet.entries) {
        element.style.setProperty(style.key, style.value);
      }

      // Update events
      for (final event in patch.eventsToSet.entries) {
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

      // Reconcile children
      for (final childPatch in patch.childrenPatches) {
        if (childPatch is InsertChildPatch) {
          final newChild = render(childPatch.node);
          element.appendChild(newChild);
        } else if (childPatch is RemoveChildPatch) {
          if (childPatch.index < element.childNodes.length) {
            final childToRemove = element.childNodes.item(childPatch.index);
            if (childToRemove != null) {
              element.removeChild(childToRemove);
            }
          }
        } else if (childPatch is PatchChildPatch) {
          if (childPatch.index < element.childNodes.length) {
            final childToPatch = element.childNodes.item(childPatch.index);
            if (childToPatch != null) {
              _applyPatch(childToPatch, childPatch.patch);
            }
          }
        }
      }
    }
  }
}

class _DomVisitor implements MantleNodeVisitor<web.Node> {
  const _DomVisitor();

  @override
  web.Node visitElement(MantleElementNode node) {
    final element = web.document.createElement(node.tag) as web.HTMLElement;

    if (node.id != null) element.id = node.id!;
    if (node.key != null) {
      element.setAttribute('data-mantle-key', node.key.toString());
    }
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
      // Validate element tag or key if present
      final serverTag = domElement.tagName.toLowerCase();
      if (serverTag != node.tag.toLowerCase()) {
        // Tag mismatch: patch or replace safely
        return;
      }

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
