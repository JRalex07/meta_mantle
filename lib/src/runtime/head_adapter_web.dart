import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../core/head_tag.dart';
import 'head_adapter_contract.dart';

HeadAdapter createHeadAdapter() => _WebHeadAdapter();

class _WebHeadAdapter implements HeadAdapter {
  static const _ownerAttribute = 'data-mm-owner';
  static const _keyAttribute = 'data-mm-key';
  static const _ownerValue = 'meta_mantle';

  static const _legacyOwnerAttribute = 'data-fwh-owner';
  static const _legacyKeyAttribute = 'data-fwh-key';
  static const _legacyOwnerValue = 'flutter_web_head';

  bool _capturedOriginalLanguage = false;
  String? _originalLanguage;
  final Map<String, _OriginalElementSnapshot> _originalElements = {};

  @override
  bool get isSupported => true;

  @override
  void apply(List<HeadTag> tags) {
    final head = web.document.head;
    if (head == null) return;

    final languageTags = tags.where((tag) => tag.tagName == 'html');
    final languageTag = languageTags.isEmpty ? null : languageTags.first;
    if (languageTag == null) {
      _restoreOriginalLanguage();
    }

    final desiredKeys = tags.map((tag) => tag.key).toSet();
    final owned = web.document.querySelectorAll(
      '[$_ownerAttribute="$_ownerValue"], [$_legacyOwnerAttribute="$_legacyOwnerValue"]',
    );
    for (var i = owned.length - 1; i >= 0; i--) {
      final element = owned.item(i) as web.Element?;
      if (element == null) continue;
      final key =
          element.getAttribute(_keyAttribute) ??
          element.getAttribute(_legacyKeyAttribute);
      if (key != null && !desiredKeys.contains(key)) {
        final original = _originalElements.remove(key);
        if (original != null) {
          _restoreElement(original);
        } else {
          element.remove();
        }
      }
    }

    for (final tag in tags) {
      if (tag.tagName == 'html') {
        final root = web.document.documentElement;
        final language = tag.attributes['lang'];
        if (root != null && language != null) {
          if (!_capturedOriginalLanguage) {
            _originalLanguage = root.getAttribute('lang');
            _capturedOriginalLanguage = true;
          }
          root.setAttribute('lang', language);
        }
        continue;
      }
      final element = _findOrCreate(tag);
      _applyAttributes(element, tag);
      if (tag.tagName == 'title' || tag.tagName == 'script') {
        final newText = tag.textContent ?? '';
        if (element.textContent != newText) {
          element.textContent = newText;
        }
      }
    }
  }

  web.Element _findOrCreate(HeadTag tag) {
    final head = web.document.head!;
    final owned = web.document.querySelectorAll(
      '[$_ownerAttribute="$_ownerValue"], [$_legacyOwnerAttribute="$_legacyOwnerValue"]',
    );
    for (var i = 0; i < owned.length; i++) {
      final element = owned.item(i) as web.Element?;
      if (element?.getAttribute(_keyAttribute) == tag.key) return element!;
    }

    final adopted = _findSemanticMatch(tag);
    if (adopted != null) {
      _originalElements.putIfAbsent(tag.key, () => _snapshotElement(adopted));
      return adopted;
    }

    final element = web.document.createElement(tag.tagName);
    head.appendChild(element);
    return element;
  }

  web.Element? _findSemanticMatch(HeadTag tag) {
    if (tag.tagName == 'title') {
      return web.document.querySelector('head title');
    }
    if (tag.tagName == 'meta') {
      final keyAttribute = tag.attributes.containsKey('name')
          ? 'name'
          : tag.attributes.containsKey('property')
          ? 'property'
          : tag.attributes.containsKey('http-equiv')
          ? 'http-equiv'
          : null;
      if (keyAttribute == null) return null;
      final value = tag.attributes[keyAttribute];
      final nodes = web.document.querySelectorAll('head meta');
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes.item(i) as web.Element?;
        if (node?.getAttribute(_ownerAttribute) == _ownerValue) continue;
        if (node?.getAttribute(keyAttribute) == value) return node;
      }
    }
    if (tag.tagName == 'link') {
      final rel = tag.attributes['rel'];
      final hrefLang = tag.attributes['hreflang'];
      final nodes = web.document.querySelectorAll('head link');
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes.item(i) as web.Element?;
        if (node?.getAttribute(_ownerAttribute) == _ownerValue) continue;
        if (node == null || node.getAttribute('rel') != rel) continue;
        if (rel == 'canonical') return node;
        if (rel == 'alternate') {
          if (hrefLang != null && node.getAttribute('hreflang') == hrefLang) {
            return node;
          }
          continue;
        }
        if (rel == 'icon' || rel == 'apple-touch-icon' || rel == 'mask-icon') {
          if (node.getAttribute('sizes') == tag.attributes['sizes'] &&
              node.getAttribute('type') == tag.attributes['type'] &&
              node.getAttribute('href') == tag.attributes['href']) {
            return node;
          }
          continue;
        }
        if (node.getAttribute('href') == tag.attributes['href']) return node;
      }
    }
    return null;
  }

  void _applyAttributes(web.Element element, HeadTag tag) {
    if (element.getAttribute(_ownerAttribute) != _ownerValue) {
      element.setAttribute(_ownerAttribute, _ownerValue);
    }
    if (element.getAttribute(_keyAttribute) != tag.key) {
      element.setAttribute(_keyAttribute, tag.key);
    }

    final desired = Map<String, String>.from(tag.attributes);
    desired[_ownerAttribute] = _ownerValue;
    desired[_keyAttribute] = tag.key;

    final managedAttributes = switch (tag.tagName) {
      'meta' => const {'name', 'property', 'http-equiv', 'content', 'charset'},
      'link' => const {
        'rel',
        'href',
        'hreflang',
        'type',
        'sizes',
        'media',
        'as',
        'crossorigin',
        'referrerpolicy',
        'integrity',
      },
      'script' => const {'type'},
      _ => const <String>{},
    };
    for (final name in managedAttributes) {
      if (!desired.containsKey(name) && element.hasAttribute(name)) {
        element.removeAttribute(name);
      }
    }
    desired.forEach((name, value) {
      if (element.getAttribute(name) != value) {
        element.setAttribute(name, value);
      }
    });
  }

  _OriginalElementSnapshot _snapshotElement(web.Element element) {
    final attributes = <String, String>{};
    final source = element.attributes;
    for (var i = 0; i < source.length; i++) {
      final attribute = source.item(i);
      if (attribute != null) {
        attributes[attribute.name] = attribute.value;
      }
    }
    return _OriginalElementSnapshot(
      element: element,
      attributes: attributes,
      textContent: element.textContent,
    );
  }

  void _restoreElement(_OriginalElementSnapshot snapshot) {
    final element = snapshot.element;
    final attributes = element.attributes;
    for (var i = attributes.length - 1; i >= 0; i--) {
      final attribute = attributes.item(i);
      if (attribute != null) element.removeAttribute(attribute.name);
    }
    snapshot.attributes.forEach(
      (name, value) => element.setAttribute(name, value),
    );
    element.textContent = snapshot.textContent ?? '';
  }

  void _restoreOriginalLanguage() {
    if (!_capturedOriginalLanguage) return;
    final root = web.document.documentElement;
    if (root != null) {
      if (_originalLanguage == null) {
        root.removeAttribute('lang');
      } else {
        root.setAttribute('lang', _originalLanguage!);
      }
    }
    _capturedOriginalLanguage = false;
    _originalLanguage = null;
  }

  @override
  void clear() {
    _restoreOriginalLanguage();
    final owned = web.document.querySelectorAll(
      '[$_ownerAttribute="$_ownerValue"], [$_legacyOwnerAttribute="$_legacyOwnerValue"]',
    );
    for (var i = owned.length - 1; i >= 0; i--) {
      final element = owned.item(i) as web.Element?;
      if (element == null) continue;
      final key = element.getAttribute(_keyAttribute);
      final original = key == null ? null : _originalElements.remove(key);
      if (original != null) {
        _restoreElement(original);
      } else {
        element.remove();
      }
    }
    _originalElements.clear();
  }

  bool _markedReady = false;

  @override
  void markReady() {
    if (_markedReady) return;
    _markedReady = true;

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
}

class _OriginalElementSnapshot {
  const _OriginalElementSnapshot({
    required this.element,
    required this.attributes,
    required this.textContent,
  });

  final web.Element element;
  final Map<String, String> attributes;
  final String? textContent;
}
