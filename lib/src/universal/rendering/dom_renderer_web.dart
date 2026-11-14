import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../ir/mantle_diff.dart';
import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import 'renderer_contract.dart';

final Expando<Map<String, JSFunction>> _elementListeners =
    Expando<Map<String, JSFunction>>();

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
    unmount(container);
    final domNode = render(node);
    container.appendChild(domNode);
  }

  /// Unmounts the target DOM container, disposing all attached event listeners and clearing children.
  void unmount(web.Element container) {
    _cleanListenersRecursive(container);
    container.textContent = '';
  }

  void _cleanListenersRecursive(web.Node node) {
    if (node.isA<web.HTMLElement>()) {
      final el = node as web.HTMLElement;
      final listeners = _elementListeners[el];
      if (listeners != null) {
        for (final entry in listeners.entries) {
          el.removeEventListener(entry.key, entry.value);
        }
        listeners.clear();
      }
    }
    final children = node.childNodes;
    for (var i = 0; i < children.length; i++) {
      final child = children.item(i);
      if (child != null) _cleanListenersRecursive(child);
    }
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
        _cleanListenersRecursive(targetDom);
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

      // Update events: remove removed listeners
      final activeListeners = _elementListeners[element] ??=
          <String, JSFunction>{};
      for (final eventName in patch.eventsToRemove) {
        final existingJsFn = activeListeners.remove(eventName);
        if (existingJsFn != null) {
          element.removeEventListener(eventName, existingJsFn);
        }
      }

      // Update events: set or replace listeners
      for (final event in patch.eventsToSet.entries) {
        final eventName = event.key;
        final callback = event.value;

        final existingJsFn = activeListeners.remove(eventName);
        if (existingJsFn != null) {
          element.removeEventListener(eventName, existingJsFn);
        }

        final jsFn = ((web.Event e) {
          Object? value;
          if (element.tagName.toLowerCase() == 'input') {
            final input = element as web.HTMLInputElement;
            value = input.type == 'checkbox' ? input.checked : input.value;
          } else if (element.tagName.toLowerCase() == 'select') {
            final select = element as web.HTMLSelectElement;
            value = select.value;
          } else if (element.tagName.toLowerCase() == 'textarea') {
            final textarea = element as web.HTMLTextAreaElement;
            value = textarea.value;
          }
          callback(
            MantleEvent(
              type: eventName,
              value: value,
              targetId: element.id.isNotEmpty ? element.id : null,
            ),
          );
        }).toJS;

        activeListeners[eventName] = jsFn;
        element.addEventListener(eventName, jsFn);
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
              _cleanListenersRecursive(childToRemove);
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
    if (node.events.isNotEmpty) {
      final activeListeners = _elementListeners[element] ??=
          <String, JSFunction>{};
      for (final event in node.events.entries) {
        final eventName = event.key;
        final callback = event.value;

        final jsFn = ((web.Event e) {
          Object? value;
          if (element.tagName.toLowerCase() == 'input') {
            final input = element as web.HTMLInputElement;
            value = input.type == 'checkbox' ? input.checked : input.value;
          } else if (element.tagName.toLowerCase() == 'select') {
            final select = element as web.HTMLSelectElement;
            value = select.value;
          } else if (element.tagName.toLowerCase() == 'textarea') {
            final textarea = element as web.HTMLTextAreaElement;
            value = textarea.value;
          }
          callback(
            MantleEvent(
              type: eventName,
              value: value,
              targetId: element.id.isNotEmpty ? element.id : null,
            ),
          );
        }).toJS;

        activeListeners[eventName] = jsFn;
        element.addEventListener(eventName, jsFn);
      }
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
      final serverTag = domElement.tagName.toLowerCase();

      // 1. Tag Mismatch Recovery: if server tag does not match client component tag, replace it
      if (serverTag != node.tag.toLowerCase()) {
        final newDom = const MantleDomRenderer().render(node);
        domElement.parentNode?.replaceChild(newDom, domElement);
        return;
      }

      // 2. Stable Node Identity: check key attribute
      if (node.key != null) {
        final existingKey = domElement.getAttribute('data-mantle-key');
        if (existingKey != null && existingKey != node.key.toString()) {
          final newDom = const MantleDomRenderer().render(node);
          domElement.parentNode?.replaceChild(newDom, domElement);
          return;
        }
        domElement.setAttribute('data-mantle-key', node.key.toString());
      }

      // 3. Attribute Reconciliation
      if (node.id != null && domElement.id != node.id) {
        domElement.id = node.id!;
      }
      for (final attr in node.attributes.entries) {
        if (domElement.getAttribute(attr.key) != attr.value) {
          domElement.setAttribute(attr.key, attr.value);
        }
      }
      for (final cls in node.classes) {
        if (!domElement.classList.contains(cls)) {
          domElement.classList.add(cls);
        }
      }

      // 4. Style Reconciliation
      if (node.styles.isNotEmpty && domElement.isA<web.HTMLElement>()) {
        final styleDeclaration = (domElement as web.HTMLElement).style;
        for (final entry in node.styles.entries) {
          styleDeclaration.setProperty(entry.key, entry.value);
        }
      }

      // 5. Event Listener Registration (with single-registration guard)
      if (node.events.isNotEmpty &&
          domElement.getAttribute('data-mantle-hydrated') != 'true') {
        domElement.setAttribute('data-mantle-hydrated', 'true');
        final activeListeners = _elementListeners[domElement] ??=
            <String, JSFunction>{};
        for (final event in node.events.entries) {
          final eventName = event.key;
          final callback = event.value;

          final jsFn = ((web.Event e) {
            Object? value;
            if (domElement.tagName.toLowerCase() == 'input') {
              final input = domElement as web.HTMLInputElement;
              value = input.type == 'checkbox' ? input.checked : input.value;
            } else if (domElement.tagName.toLowerCase() == 'select') {
              final select = domElement as web.HTMLSelectElement;
              value = select.value;
            } else if (domElement.tagName.toLowerCase() == 'textarea') {
              final textarea = domElement as web.HTMLTextAreaElement;
              value = textarea.value;
            }
            callback(
              MantleEvent(
                type: eventName,
                value: value,
                targetId: domElement.id.isNotEmpty ? domElement.id : null,
              ),
            );
          }).toJS;

          activeListeners[eventName] = jsFn;
          domElement.addEventListener(eventName, jsFn);
        }
      }

      // 6. Child Insertion, Removal, and Text Node Reconciliation
      final domChildren = <web.Node>[];
      var childCursor = domElement.firstChild;
      while (childCursor != null) {
        domChildren.add(childCursor);
        childCursor = childCursor.nextSibling;
      }

      var domIdx = 0;
      for (final childNode in node.children) {
        if (childNode is MantleTextNode) {
          if (domIdx < domChildren.length &&
              domChildren[domIdx].nodeType == 3) {
            // Reconcile text
            final textNode = domChildren[domIdx];
            if (textNode.textContent != childNode.text) {
              textNode.textContent = childNode.text;
            }
            domIdx++;
          } else {
            // Insert missing text node
            final newText = web.document.createTextNode(childNode.text);
            if (domIdx < domChildren.length) {
              domElement.insertBefore(newText, domChildren[domIdx]);
            } else {
              domElement.appendChild(newText);
            }
          }
        } else if (childNode is MantleElementNode) {
          if (domIdx < domChildren.length &&
              domChildren[domIdx].isA<web.Element>()) {
            final childElement = domChildren[domIdx] as web.Element;
            _hydrateRecursive(childElement, childNode);
            domIdx++;
          } else {
            // Insert missing element
            final newElement = const MantleDomRenderer().render(childNode);
            if (domIdx < domChildren.length) {
              domElement.insertBefore(newElement, domChildren[domIdx]);
            } else {
              domElement.appendChild(newElement);
            }
          }
        }
      }

      // Remove excess server DOM nodes
      while (domIdx < domChildren.length) {
        domElement.removeChild(domChildren[domIdx]);
        domIdx++;
      }
    }
  }
}
