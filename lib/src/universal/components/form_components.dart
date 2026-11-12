import '../ir/mantle_events.dart';
import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

/// Alias for [MantleTextField] matching HTML input nomenclature.
typedef MantleInput = MantleTextField;

class MantleTextField extends StatelessMantleComponent {
  const MantleTextField({
    this.value = '',
    this.placeholder = '',
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.padding = const MantleEdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.border = const MantleBorder.all(color: MantleColor.grey),
    this.borderRadius = const MantleBorderRadius.circular(4),
    super.key,
  });

  final String value;
  final String placeholder;
  final MantleValueCallback<String>? onChanged;
  final MantleValueCallback<String>? onSubmitted;
  final bool obscureText;
  final MantleEdgeInsets padding;
  final MantleBorder border;
  final MantleBorderRadius borderRadius;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'border': border.toCss(),
      'border-radius': borderRadius.toCss(),
      'font-size': '14px',
      'outline': 'none',
      'box-sizing': 'border-box',
      'width': '100%',
    };

    final attributes = <String, String>{
      'type': obscureText ? 'password' : 'text',
      'placeholder': placeholder,
      'value': value,
    };

    final events = <String, MantleEventCallback>{};
    if (onChanged != null) {
      events['input'] = (e) {
        onChanged!(e.value?.toString() ?? '');
      };
    }
    if (onSubmitted != null) {
      events['keydown'] = (e) {
        if (e.type == 'Enter' || e.value == 'Enter') {
          onSubmitted!(value);
        }
      };
    }

    return MantleElementNode(
      tag: 'input',
      attributes: attributes,
      styles: styles,
      events: events,
      key: key,
    );
  }
}

class MantleCheckbox extends StatelessMantleComponent {
  const MantleCheckbox({
    required this.value,
    this.onChanged,
    this.label,
    super.key,
  });

  final bool value;
  final MantleValueCallback<bool>? onChanged;
  final String? label;

  @override
  MantleNode build(MantleContext context) {
    final attributes = <String, String>{'type': 'checkbox'};
    if (value) attributes['checked'] = 'checked';
    if (onChanged == null) attributes['disabled'] = 'disabled';

    final events = <String, MantleEventCallback>{};
    if (onChanged != null) {
      events['change'] = (e) {
        onChanged!(e.value == true || e.value == 'true');
      };
    }

    final inputNode = MantleElementNode(
      tag: 'input',
      attributes: attributes,
      events: events,
      key: key,
    );

    if (label != null) {
      return MantleElementNode(
        tag: 'label',
        styles: {
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '8px',
          'cursor': 'pointer',
        },
        children: [inputNode, MantleTextNode(label!)],
      );
    }
    return inputNode;
  }
}

class MantleSwitch extends StatelessMantleComponent {
  const MantleSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    super.key,
  });

  final bool value;
  final MantleValueCallback<bool> onChanged;
  final String? label;

  @override
  MantleNode build(MantleContext context) {
    return MantleCheckbox(
      value: value,
      onChanged: onChanged,
      label: label,
      key: key,
    ).toNode(context);
  }
}

class MantleRadio<T> extends StatelessMantleComponent {
  const MantleRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    super.key,
  });

  final T value;
  final T? groupValue;
  final MantleValueCallback<T> onChanged;
  final String? label;

  @override
  MantleNode build(MantleContext context) {
    final isSelected = value == groupValue;
    final attributes = <String, String>{'type': 'radio'};
    if (isSelected) attributes['checked'] = 'checked';

    final inputNode = MantleElementNode(
      tag: 'input',
      attributes: attributes,
      events: {'change': (_) => onChanged(value)},
      key: key,
    );

    if (label != null) {
      return MantleElementNode(
        tag: 'label',
        styles: {
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '8px',
          'cursor': 'pointer',
        },
        children: [inputNode, MantleTextNode(label!)],
      );
    }
    return inputNode;
  }
}

class MantleSelect<T> extends StatelessMantleComponent {
  const MantleSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final MantleValueCallback<T> onChanged;

  @override
  MantleNode build(MantleContext context) {
    final optionNodes = <MantleNode>[];
    for (final entry in options.entries) {
      final attrs = <String, String>{'value': entry.key.toString()};
      if (entry.key == value) attrs['selected'] = 'selected';
      optionNodes.add(
        MantleElementNode(
          tag: 'option',
          attributes: attrs,
          children: [MantleTextNode(entry.value)],
        ),
      );
    }

    return MantleElementNode(
      tag: 'select',
      styles: {
        'padding': '8px 12px',
        'border-radius': '4px',
        'border': '1px solid #ccc',
        'font-size': '14px',
      },
      events: {
        'change': (e) {
          final raw = e.value?.toString();
          for (final optKey in options.keys) {
            if (optKey.toString() == raw) {
              onChanged(optKey);
              break;
            }
          }
        },
      },
      children: optionNodes,
      key: key,
    );
  }
}

class MantleForm extends StatelessMantleComponent {
  const MantleForm({required this.child, this.onSubmit, super.key});

  final MantleComponent child;
  final MantleVoidCallback? onSubmit;

  @override
  MantleNode build(MantleContext context) {
    final events = <String, MantleEventCallback>{};
    if (onSubmit != null) {
      events['submit'] = (_) => onSubmit!();
    }

    return MantleElementNode(
      tag: 'form',
      events: events,
      children: [child.toNode(context)],
      key: key,
    );
  }
}
