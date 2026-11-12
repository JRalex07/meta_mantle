import 'package:flutter/material.dart';

import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'renderer_contract.dart';

/// Flutter widget renderer for [MantleNode] trees.
/// Enables portable Mantle components to render natively on Android, iOS,
/// macOS, Windows, Linux, and Flutter Web CanvasKit/Skwasm.
class MantleFlutterRenderer implements MantleRenderer<Widget> {
  const MantleFlutterRenderer();

  @override
  Widget render(MantleNode node) {
    return node.accept(const _FlutterVisitor());
  }
}

class _FlutterVisitor implements MantleNodeVisitor<Widget> {
  const _FlutterVisitor();

  @override
  Widget visitElement(MantleElementNode node) {
    // 1. Text elements (h1-h6, p, label)
    if (const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'label'}
        .contains(node.tag)) {
      final textContent = _extractTextContent(node);
      final style = _parseTextStyle(node.styles);
      return Text(textContent, style: style);
    }

    // 2. Buttons
    if (node.tag == 'button') {
      final onClick = node.events['click'];
      final childrenWidgets = node.children.map((c) => c.accept(this)).toList();
      final childWidget = childrenWidgets.length == 1
          ? childrenWidgets.first
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: childrenWidgets,
            );

      final bgColor = _parseColor(node.styles['background-color']);
      final textColor = _parseColor(node.styles['color']);

      return ElevatedButton(
        onPressed: onClick != null
            ? () => onClick(const MantleEvent(type: 'click'))
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: _parseBorderRadius(node.styles['border-radius']) ??
                BorderRadius.zero,
          ),
        ),
        child: childWidget,
      );
    }

    // 3. Images
    if (node.tag == 'img') {
      final src = node.attributes['src'] ?? '';
      final width = _parseDouble(node.styles['width']);
      final height = _parseDouble(node.styles['height']);
      return Image.network(
        src,
        width: width,
        height: height,
        fit: _parseBoxFit(node.styles['object-fit']),
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }

    // 4. Links
    if (node.tag == 'a') {
      final onClick = node.events['click'];
      final childrenWidgets = node.children.map((c) => c.accept(this)).toList();
      return InkWell(
        onTap: onClick != null
            ? () => onClick(const MantleEvent(type: 'click'))
            : null,
        child: childrenWidgets.length == 1
            ? childrenWidgets.first
            : Row(mainAxisSize: MainAxisSize.min, children: childrenWidgets),
      );
    }

    // 5. Input fields
    if (node.tag == 'input') {
      final type = node.attributes['type'] ?? 'text';
      if (type == 'checkbox') {
        final checked = node.attributes['checked'] != null;
        final onChange = node.events['change'];
        return Checkbox(
          value: checked,
          onChanged: onChange != null
              ? (val) => onChange(MantleEvent(type: 'change', value: val))
              : null,
        );
      }

      final onInput = node.events['input'];
      return TextFormField(
        initialValue: node.attributes['value'],
        obscureText: type == 'password',
        decoration: InputDecoration(
          hintText: node.attributes['placeholder'],
          border: const OutlineInputBorder(),
        ),
        onChanged: onInput != null
            ? (val) => onInput(MantleEvent(type: 'input', value: val))
            : null,
      );
    }

    // 6. Select dropdowns
    if (node.tag == 'select') {
      final onChange = node.events['change'];
      final options = <DropdownMenuItem<String>>[];
      String? selectedVal;
      for (final child in node.children) {
        if (child is MantleElementNode && child.tag == 'option') {
          final val = child.attributes['value'] ?? '';
          if (child.attributes['selected'] != null) selectedVal = val;
          final text = _extractTextContent(child);
          options.add(DropdownMenuItem(value: val, child: Text(text)));
        }
      }
      return DropdownButton<String>(
        value: selectedVal ?? (options.isNotEmpty ? options.first.value : null),
        items: options,
        onChanged: onChange != null
            ? (val) => onChange(MantleEvent(type: 'change', value: val))
            : null,
      );
    }

    // 7. Forms
    if (node.tag == 'form') {
      final childrenWidgets = node.children.map((c) => c.accept(this)).toList();
      return Form(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: childrenWidgets,
        ),
      );
    }

    // 8. Generic layout elements (div, section, main, header, nav, aside, etc.)
    final childrenWidgets = node.children.map((c) => c.accept(this)).toList();

    // Check flex direction
    final display = node.styles['display'];
    if (display == 'flex') {
      final direction = node.styles['flex-direction'];
      final mainAlign = _parseMainAlignment(node.styles['justify-content']);
      final crossAlign = _parseCrossAlignment(node.styles['align-items']);

      if (direction == 'column') {
        return Column(
          mainAxisAlignment: mainAlign,
          crossAxisAlignment: crossAlign,
          mainAxisSize: MainAxisSize.min,
          children: childrenWidgets,
        );
      }
      return Row(
        mainAxisAlignment: mainAlign,
        crossAxisAlignment: crossAlign,
        mainAxisSize: MainAxisSize.min,
        children: childrenWidgets,
      );
    }

    if (display == 'grid') {
      final colsStr = node.styles['grid-template-columns'] ?? 'repeat(2, 1fr)';
      final match = RegExp(r'repeat\((\d+),').firstMatch(colsStr);
      final count = match != null ? int.tryParse(match.group(1)!) ?? 2 : 2;

      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: childrenWidgets,
      );
    }

    // Default container wrapper
    final width = _parseDouble(node.styles['width']);
    final height = _parseDouble(node.styles['height']);
    final padding = _parseEdgeInsets(node.styles['padding']);
    final margin = _parseEdgeInsets(node.styles['margin']);
    final bgColor = _parseColor(node.styles['background-color']);
    final borderRadius = _parseBorderRadius(node.styles['border-radius']);

    Widget current = Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
      ),
      child: childrenWidgets.length == 1
          ? childrenWidgets.first
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: childrenWidgets,
            ),
    );

    if (node.events.containsKey('click')) {
      final onClick = node.events['click']!;
      current = GestureDetector(
        onTap: () => onClick(const MantleEvent(type: 'click')),
        child: current,
      );
    }

    if (node.attributes.containsKey('aria-label') ||
        node.attributes.containsKey('role')) {
      current = Semantics(
        label: node.attributes['aria-label'],
        container: true,
        child: current,
      );
    }

    return current;
  }

  @override
  Widget visitText(MantleTextNode node) {
    TextStyle? style;
    if (node.style != null) {
      style = TextStyle(
        fontSize: node.style!.fontSize,
        color:
            node.style!.color != null ? Color(node.style!.color!.value) : null,
        fontWeight: _mapFontWeight(node.style!.fontWeight),
        fontStyle: node.style!.fontStyle == MantleFontStyle.italic
            ? FontStyle.italic
            : FontStyle.normal,
        fontFamily: node.style!.fontFamily,
        letterSpacing: node.style!.letterSpacing,
      );
    }
    return Text(node.text, style: style);
  }

  @override
  Widget visitFragment(MantleFragment node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: node.children.map((c) => c.accept(this)).toList(),
    );
  }

  String _extractTextContent(MantleElementNode node) {
    final buf = StringBuffer();
    for (final child in node.children) {
      if (child is MantleTextNode) {
        buf.write(child.text);
      } else if (child is MantleElementNode) {
        buf.write(_extractTextContent(child));
      }
    }
    return buf.toString();
  }

  double? _parseDouble(String? val) {
    if (val == null) return null;
    return double.tryParse(val.replaceAll('px', '').trim());
  }

  Color? _parseColor(String? val) {
    if (val == null) return null;
    if (val.startsWith('#')) {
      final hex = val.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    if (val.startsWith('rgba')) {
      final match = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)')
          .firstMatch(val);
      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final a = (double.parse(match.group(4)!) * 255).round();
        return Color.fromARGB(a, r, g, b);
      }
    }
    return null;
  }

  BorderRadius? _parseBorderRadius(String? val) {
    if (val == null) return null;
    final num = _parseDouble(val);
    if (num != null) return BorderRadius.circular(num);
    return null;
  }

  EdgeInsets? _parseEdgeInsets(String? val) {
    if (val == null) return null;
    final parts = val.split(' ').map((s) => _parseDouble(s) ?? 0.0).toList();
    if (parts.length == 4) {
      return EdgeInsets.fromLTRB(parts[3], parts[0], parts[1], parts[2]);
    }
    if (parts.length == 1) {
      return EdgeInsets.all(parts[0]);
    }
    return null;
  }

  BoxFit _parseBoxFit(String? val) => switch (val) {
        'cover' => BoxFit.cover,
        'contain' => BoxFit.contain,
        'fill' => BoxFit.fill,
        _ => BoxFit.cover,
      };

  MainAxisAlignment _parseMainAlignment(String? val) => switch (val) {
        'flex-start' => MainAxisAlignment.start,
        'flex-end' => MainAxisAlignment.end,
        'center' => MainAxisAlignment.center,
        'space-between' => MainAxisAlignment.spaceBetween,
        'space-around' => MainAxisAlignment.spaceAround,
        'space-evenly' => MainAxisAlignment.spaceEvenly,
        _ => MainAxisAlignment.start,
      };

  CrossAxisAlignment _parseCrossAlignment(String? val) => switch (val) {
        'flex-start' => CrossAxisAlignment.start,
        'flex-end' => CrossAxisAlignment.end,
        'center' => CrossAxisAlignment.center,
        'stretch' => CrossAxisAlignment.stretch,
        _ => CrossAxisAlignment.start,
      };

  TextStyle? _parseTextStyle(Map<String, String> styles) {
    final color = _parseColor(styles['color']);
    final fontSize = _parseDouble(styles['font-size']);
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight:
          styles.containsKey('font-weight') && styles['font-weight'] == '700'
              ? FontWeight.bold
              : FontWeight.normal,
    );
  }

  FontWeight? _mapFontWeight(MantleFontWeight? weight) => switch (weight) {
        MantleFontWeight.w100 => FontWeight.w100,
        MantleFontWeight.w200 => FontWeight.w200,
        MantleFontWeight.w300 => FontWeight.w300,
        MantleFontWeight.normal => FontWeight.normal,
        MantleFontWeight.w500 => FontWeight.w500,
        MantleFontWeight.w600 => FontWeight.w600,
        MantleFontWeight.bold => FontWeight.bold,
        MantleFontWeight.w800 => FontWeight.w800,
        MantleFontWeight.w900 => FontWeight.w900,
        null => null,
      };
}
