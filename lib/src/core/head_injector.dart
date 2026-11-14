import 'dart:convert';

import 'package:html/dom.dart' as dom;

import 'head_tag.dart';

/// Clean, deduplicating HTML document head tag injector.
/// Ensures valid HTML5 document structure, unique SEO metadata, and zero malformed tags.
class HeadInjector {
  const HeadInjector._();

  /// Injects [tags] into [document], replacing template defaults, eliminating duplicates,
  /// and ensuring valid HTML5 hierarchy.
  static void injectTags({
    required dom.Document document,
    required List<HeadTag> tags,
  }) {
    // 1. Ensure root <html> element exists
    var htmlElement = document.querySelector('html');
    if (htmlElement == null) {
      htmlElement = document.createElement('html');
      document.children.insert(0, htmlElement);
    }

    // 2. Ensure exactly one <head> element exists
    var headElement = document.querySelector('head');
    if (headElement == null) {
      headElement = document.createElement('head');
      htmlElement.children.insert(0, headElement);
    }

    // 3. Clean up any malformed elements (e.g. <html> or <body> placed inside <head>)
    for (final malformed in headElement.querySelectorAll('html, body')) {
      malformed.remove();
    }
    final bodyElement = document.querySelector('body');
    if (bodyElement != null) {
      for (final malformed in bodyElement.querySelectorAll('html, head')) {
        malformed.remove();
      }
    }

    // 4. Ensure <meta charset="UTF-8"> is at the top of <head>
    final hasCharset =
        headElement.querySelectorAll('meta[charset]').isNotEmpty ||
        headElement
            .querySelectorAll('meta')
            .any(
              (m) =>
                  m.attributes['http-equiv']?.toLowerCase() == 'content-type',
            );
    if (!hasCharset) {
      final charsetMeta = document.createElement('meta')
        ..attributes['charset'] = 'UTF-8';
      headElement.children.insert(0, charsetMeta);
    }

    // 5. Process each incoming HeadTag with strict deduplication
    for (final tag in tags) {
      // Rule A: Language declaration applies strictly to the root <html> element
      if (tag.tagName == 'html') {
        final lang = tag.attributes['lang'];
        if (lang != null && lang.isNotEmpty) {
          htmlElement.attributes['lang'] = lang;
          document.documentElement?.attributes['lang'] = lang;
        }
        continue;
      }

      // Rule B: Title element must be unique
      if (tag.tagName == 'title') {
        final existingTitles = headElement.querySelectorAll('title');
        if (existingTitles.isNotEmpty) {
          existingTitles.first.text = tag.textContent ?? '';
          for (var i = 1; i < existingTitles.length; i++) {
            existingTitles[i].remove();
          }
        } else {
          final t = document.createElement('title')
            ..text = tag.textContent ?? '';
          headElement.append(t);
        }
        continue;
      }

      // Rule C: Canonical URL must be unique
      if (tag.tagName == 'link' &&
          tag.attributes['rel']?.toLowerCase() == 'canonical') {
        final existingCanonicals = headElement
            .querySelectorAll('link')
            .where((l) => l.attributes['rel']?.toLowerCase() == 'canonical')
            .toList();
        final canonicalUrl = tag.attributes['href'] ?? '';
        if (existingCanonicals.isNotEmpty) {
          existingCanonicals.first.attributes['href'] = canonicalUrl;
          for (var i = 1; i < existingCanonicals.length; i++) {
            existingCanonicals[i].remove();
          }
        } else {
          final link = document.createElement('link')
            ..attributes['rel'] = 'canonical'
            ..attributes['href'] = canonicalUrl;
          headElement.append(link);
        }
        continue;
      }

      // Rule D: Meta Description must be unique
      if (tag.tagName == 'meta' &&
          tag.attributes['name']?.toLowerCase() == 'description') {
        final existingDescriptions = headElement
            .querySelectorAll('meta')
            .where((m) => m.attributes['name']?.toLowerCase() == 'description')
            .toList();
        final descContent = tag.attributes['content'] ?? '';
        if (existingDescriptions.isNotEmpty) {
          existingDescriptions.first.attributes['content'] = descContent;
          for (var i = 1; i < existingDescriptions.length; i++) {
            existingDescriptions[i].remove();
          }
        } else {
          final meta = document.createElement('meta')
            ..attributes['name'] = 'description'
            ..attributes['content'] = descContent;
          headElement.append(meta);
        }
        continue;
      }

      // Rule E: Meta Robots must be unique
      if (tag.tagName == 'meta' &&
          tag.attributes['name']?.toLowerCase() == 'robots') {
        final existingRobots = headElement
            .querySelectorAll('meta')
            .where((m) => m.attributes['name']?.toLowerCase() == 'robots')
            .toList();
        final robotsContent = tag.attributes['content'] ?? '';
        if (existingRobots.isNotEmpty) {
          existingRobots.first.attributes['content'] = robotsContent;
          for (var i = 1; i < existingRobots.length; i++) {
            existingRobots[i].remove();
          }
        } else {
          final meta = document.createElement('meta')
            ..attributes['name'] = 'robots'
            ..attributes['content'] = robotsContent;
          headElement.append(meta);
        }
        continue;
      }

      // Rule F: Open Graph and Twitter Card tags
      if (tag.tagName == 'meta') {
        final ogProp = tag.attributes['property']?.toLowerCase();
        if (ogProp != null && ogProp.startsWith('og:')) {
          final primaryOg = {
            'og:title',
            'og:description',
            'og:url',
            'og:image',
            'og:site_name',
            'og:type',
          };
          if (primaryOg.contains(ogProp)) {
            final existing = headElement
                .querySelectorAll('meta')
                .where((m) => m.attributes['property']?.toLowerCase() == ogProp)
                .toList();
            if (existing.isNotEmpty) {
              existing.first.attributes['content'] =
                  tag.attributes['content'] ?? '';
              for (var i = 1; i < existing.length; i++) {
                existing[i].remove();
              }
              continue;
            }
          }
        }

        final twName = tag.attributes['name']?.toLowerCase();
        if (twName != null && twName.startsWith('twitter:')) {
          final primaryTw = {
            'twitter:card',
            'twitter:title',
            'twitter:description',
            'twitter:image',
            'twitter:site',
            'twitter:creator',
          };
          if (primaryTw.contains(twName)) {
            final existing = headElement
                .querySelectorAll('meta')
                .where((m) => m.attributes['name']?.toLowerCase() == twName)
                .toList();
            if (existing.isNotEmpty) {
              existing.first.attributes['content'] =
                  tag.attributes['content'] ?? '';
              for (var i = 1; i < existing.length; i++) {
                existing[i].remove();
              }
              continue;
            }
          }
        }

        final metaName = tag.attributes['name']?.toLowerCase();
        if (metaName != null &&
            const {
              'keywords',
              'author',
              'theme-color',
              'generator',
            }.contains(metaName)) {
          final existing = headElement
              .querySelectorAll('meta')
              .where((m) => m.attributes['name']?.toLowerCase() == metaName)
              .toList();
          if (existing.isNotEmpty) {
            existing.first.attributes['content'] =
                tag.attributes['content'] ?? '';
            for (var i = 1; i < existing.length; i++) {
              existing[i].remove();
            }
            continue;
          }
        }
      }

      // Rule G: JSON-LD Structured Data
      if (tag.tagName == 'script' &&
          tag.attributes['type']?.toLowerCase() == 'application/ld+json') {
        String? newType;
        try {
          final decoded = json.decode(tag.textContent ?? '');
          if (decoded is Map && decoded.containsKey('@type')) {
            newType = decoded['@type']?.toString();
          }
        } catch (_) {}

        if (newType != null) {
          // Check if a JSON-LD block with the same @type already exists in head
          dom.Element? matchedScript;
          for (final existingScript in headElement.querySelectorAll(
            'script[type="application/ld+json"]',
          )) {
            try {
              final d = json.decode(existingScript.text.trim());
              if (d is Map && d['@type'] == newType) {
                matchedScript = existingScript;
                break;
              }
            } catch (_) {}
          }
          if (matchedScript != null) {
            matchedScript.text = tag.textContent ?? '';
            continue;
          }
        }
      }

      // Default: create element, copy attributes & content, and append to <head>
      final el = document.createElement(tag.tagName);
      for (final attr in tag.attributes.entries) {
        el.attributes[attr.key] = attr.value;
      }
      if (tag.textContent != null) {
        el.text = tag.textContent!;
      }
      headElement.append(el);
    }

    // Final safety clean: ensure no malformed elements survived in <head>
    for (final stray in headElement.querySelectorAll('html, body')) {
      stray.remove();
    }
  }
}
