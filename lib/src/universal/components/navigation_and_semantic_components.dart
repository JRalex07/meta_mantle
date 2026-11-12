import '../ir/mantle_node.dart';
import '../ir/mantle_style.dart';
import 'mantle_component.dart';

class MantlePage extends StatelessMantleComponent {
  const MantlePage({
    required this.children,
    this.title,
    this.description,
    this.padding = const MantleEdgeInsets.all(16),
    this.backgroundColor,
    super.key,
  });

  final List<MantleComponent> children;
  final String? title;
  final String? description;
  final MantleEdgeInsets padding;
  final MantleColor? backgroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'padding': padding.toCssPadding(),
      'min-height': '100vh',
      'box-sizing': 'border-box',
    };
    if (backgroundColor != null) {
      styles['background-color'] = backgroundColor!.toCssRgba();
    }

    return MantleElementNode(
      tag: 'main',
      classes: const ['mantle-page'],
      styles: styles,
      children: children.map((c) => c.toNode(context)).toList(),
      key: key,
    );
  }
}

class MantleAppBar extends StatelessMantleComponent {
  const MantleAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.backgroundColor = MantleColor.blue,
    this.foregroundColor = MantleColor.white,
    super.key,
  });

  final String title;
  final MantleComponent? leading;
  final List<MantleComponent> actions;
  final MantleColor backgroundColor;
  final MantleColor foregroundColor;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'space-between',
      'padding': '12px 20px',
      'background-color': backgroundColor.toCssRgba(),
      'color': foregroundColor.toCssRgba(),
      'box-shadow': '0 2px 4px rgba(0,0,0,0.1)',
    };

    final leftGroup = <MantleNode>[];
    if (leading != null) leftGroup.add(leading!.toNode(context));
    leftGroup.add(
      MantleElementNode(
        tag: 'h1',
        styles: {'font-size': '20px', 'margin': '0', 'font-weight': 'bold'},
        children: [MantleTextNode(title)],
      ),
    );

    return MantleElementNode(
      tag: 'header',
      classes: const ['mantle-app-bar'],
      styles: styles,
      children: [
        MantleElementNode(
          tag: 'div',
          styles: {'display': 'flex', 'align-items': 'center', 'gap': '12px'},
          children: leftGroup,
        ),
        MantleElementNode(
          tag: 'div',
          styles: {'display': 'flex', 'align-items': 'center', 'gap': '12px'},
          children: actions.map((a) => a.toNode(context)).toList(),
        ),
      ],
      key: key,
    );
  }
}

class MantleRouteLink extends StatelessMantleComponent {
  const MantleRouteLink({
    required this.path,
    this.label,
    this.child,
    this.style,
    super.key,
  });

  final String path;
  final String? label;
  final MantleComponent? child;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final styles = <String, String>{
      'text-decoration': 'none',
      'cursor': 'pointer',
      ...style?.toCssProperties() ?? {'color': '#2196f3'},
    };

    final children = <MantleNode>[];
    if (child != null) {
      children.add(child!.toNode(context));
    } else if (label != null) {
      children.add(MantleTextNode(label!));
    }

    return MantleElementNode(
      tag: 'a',
      attributes: {'href': path},
      styles: styles,
      events: {
        'click': (e) {
          context.go(path);
        },
      },
      children: children,
      key: key,
    );
  }
}

enum MantleLandmarkType { header, nav, main, footer, aside, section, article }

class MantleLandmark extends StatelessMantleComponent {
  const MantleLandmark({
    required this.type,
    required this.child,
    this.id,
    this.classes = const [],
    super.key,
  });

  final MantleLandmarkType type;
  final MantleComponent child;
  final String? id;
  final List<String> classes;

  @override
  MantleNode build(MantleContext context) {
    return MantleElementNode(
      tag: type.name,
      id: id,
      classes: classes,
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleSemantics extends StatelessMantleComponent {
  const MantleSemantics({
    required this.child,
    this.label,
    this.role,
    this.liveRegion,
    super.key,
  });

  final MantleComponent child;
  final String? label;
  final String? role;
  final String? liveRegion;

  @override
  MantleNode build(MantleContext context) {
    final attrs = <String, String>{};
    if (label != null) attrs['aria-label'] = label!;
    if (role != null) attrs['role'] = role!;
    if (liveRegion != null) attrs['aria-live'] = liveRegion!;

    return MantleElementNode(
      tag: 'div',
      attributes: attrs,
      children: [child.toNode(context)],
      key: key,
    );
  }
}

class MantleLabel extends StatelessMantleComponent {
  const MantleLabel(this.text, {this.forId, this.style, super.key});

  final String text;
  final String? forId;
  final MantleTextStyle? style;

  @override
  MantleNode build(MantleContext context) {
    final attrs = <String, String>{};
    if (forId != null) attrs['for'] = forId!;

    return MantleElementNode(
      tag: 'label',
      attributes: attrs,
      styles: style?.toCssProperties() ?? const {},
      children: [MantleTextNode(text)],
      key: key,
    );
  }
}

/// Navigation destination item used in [MantleNavigation].
class MantleNavigationItem {
  const MantleNavigationItem({
    required this.label,
    this.icon,
    this.route,
    this.badge,
  });

  final String label;
  final MantleComponent? icon;
  final String? route;
  final String? badge;
}

/// Universal navigation component (bottom nav, top bar, or side rail).
class MantleNavigation extends StatelessMantleComponent {
  const MantleNavigation({
    required this.items,
    this.currentIndex = 0,
    this.onTap,
    this.backgroundColor = MantleColor.white,
    this.selectedColor = MantleColor.blue,
    this.unselectedColor = MantleColor.grey,
    super.key,
  });

  final List<MantleNavigationItem> items;
  final int currentIndex;
  final void Function(int index)? onTap;
  final MantleColor backgroundColor;
  final MantleColor selectedColor;
  final MantleColor unselectedColor;

  @override
  MantleNode build(MantleContext context) {
    final itemNodes = <MantleNode>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = i == currentIndex;
      final color = isSelected ? selectedColor : unselectedColor;

      final children = <MantleNode>[];
      if (item.icon != null) {
        children.add(item.icon!.toNode(context));
      }
      children.add(
        MantleElementNode(
          tag: 'span',
          styles: {
            'font-size': '12px',
            'font-weight': isSelected ? '600' : 'normal',
          },
          children: [MantleTextNode(item.label)],
        ),
      );

      itemNodes.add(
        MantleElementNode(
          tag: 'button',
          classes: [
            'mantle-nav-item',
            if (isSelected) 'mantle-nav-item-selected',
          ],
          attributes: {
            'role': 'tab',
            'aria-selected': isSelected ? 'true' : 'false',
          },
          styles: {
            'display': 'flex',
            'flex-direction': 'column',
            'align-items': 'center',
            'gap': '4px',
            'background': 'none',
            'border': 'none',
            'cursor': 'pointer',
            'padding': '8px 16px',
            'color': color.toCssRgba(),
          },
          events: {
            'click': (_) {
              if (onTap != null) {
                onTap!(i);
              } else if (item.route != null) {
                context.go(item.route!);
              }
            },
          },
          children: children,
        ),
      );
    }

    return MantleElementNode(
      tag: 'nav',
      classes: const ['mantle-navigation'],
      attributes: const {'role': 'navigation'},
      styles: {
        'display': 'flex',
        'justify-content': 'space-around',
        'align-items': 'center',
        'background-color': backgroundColor.toCssRgba(),
        'border-top': '1px solid #e0e0e0',
        'padding': '6px 0',
      },
      children: itemNodes,
      key: key,
    );
  }
}

/// Universal drawer component for side navigation and menus.
class MantleDrawer extends StatelessMantleComponent {
  const MantleDrawer({
    required this.children,
    this.header,
    this.isOpen = false,
    this.onClose,
    this.width = 280,
    this.backgroundColor = MantleColor.white,
    super.key,
  });

  final List<MantleComponent> children;
  final MantleComponent? header;
  final bool isOpen;
  final void Function()? onClose;
  final double width;
  final MantleColor backgroundColor;

  @override
  MantleNode build(MantleContext context) {
    final contentNodes = <MantleNode>[];
    if (header != null) {
      contentNodes.add(header!.toNode(context));
    }
    contentNodes.addAll(children.map((c) => c.toNode(context)));

    final drawerAside = MantleElementNode(
      tag: 'aside',
      classes: ['mantle-drawer', if (isOpen) 'mantle-drawer-open'],
      attributes: const {'role': 'complementary'},
      styles: {
        'width': '${width}px',
        'height': '100vh',
        'position': 'fixed',
        'top': '0',
        'left': isOpen ? '0' : '-${width}px',
        'background-color': backgroundColor.toCssRgba(),
        'box-shadow': isOpen ? '2px 0 12px rgba(0,0,0,0.2)' : 'none',
        'transition': 'left 0.3s ease',
        'z-index': '1000',
        'overflow-y': 'auto',
      },
      children: contentNodes,
    );

    if (!isOpen) return drawerAside;

    // When open, render with backdrop overlay
    return MantleElementNode(
      tag: 'div',
      classes: const ['mantle-drawer-wrapper'],
      styles: const {
        'position': 'fixed',
        'top': '0',
        'left': '0',
        'right': '0',
        'bottom': '0',
        'z-index': '999',
      },
      children: [
        MantleElementNode(
          tag: 'div',
          classes: const ['mantle-drawer-backdrop'],
          styles: const {
            'position': 'absolute',
            'top': '0',
            'left': '0',
            'width': '100%',
            'height': '100%',
            'background-color': 'rgba(0,0,0,0.5)',
          },
          events: {if (onClose != null) 'click': (_) => onClose!()},
        ),
        drawerAside,
      ],
      key: key,
    );
  }
}

/// Single tab item within a [MantleTabs] component.
class MantleTab {
  const MantleTab({required this.title, required this.content, this.icon});

  final String title;
  final MantleComponent content;
  final MantleComponent? icon;
}

/// Universal tabs component.
class MantleTabs extends StatelessMantleComponent {
  const MantleTabs({
    required this.tabs,
    this.currentIndex = 0,
    this.onTap,
    this.activeColor = MantleColor.blue,
    super.key,
  });

  final List<MantleTab> tabs;
  final int currentIndex;
  final void Function(int index)? onTap;
  final MantleColor activeColor;

  @override
  MantleNode build(MantleContext context) {
    final headerButtons = <MantleNode>[];

    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final isActive = i == currentIndex;

      final tabChildren = <MantleNode>[];
      if (tab.icon != null) {
        tabChildren.add(tab.icon!.toNode(context));
      }
      tabChildren.add(MantleTextNode(tab.title));

      headerButtons.add(
        MantleElementNode(
          tag: 'button',
          classes: ['mantle-tab', if (isActive) 'mantle-tab-active'],
          attributes: {
            'role': 'tab',
            'aria-selected': isActive ? 'true' : 'false',
          },
          styles: {
            'padding': '10px 18px',
            'background': 'none',
            'border': 'none',
            'border-bottom': isActive
                ? '2px solid ${activeColor.toCssRgba()}'
                : '2px solid transparent',
            'color': isActive ? activeColor.toCssRgba() : '#666',
            'font-weight': isActive ? 'bold' : 'normal',
            'cursor': 'pointer',
            'display': 'inline-flex',
            'align-items': 'center',
            'gap': '6px',
          },
          events: {if (onTap != null) 'click': (_) => onTap!(i)},
          children: tabChildren,
        ),
      );
    }

    final headerBar = MantleElementNode(
      tag: 'div',
      classes: const ['mantle-tabs-header'],
      attributes: const {'role': 'tablist'},
      styles: {
        'display': 'flex',
        'border-bottom': '1px solid #e0e0e0',
        'gap': '8px',
      },
      children: headerButtons,
    );

    final activeContent = (currentIndex >= 0 && currentIndex < tabs.length)
        ? tabs[currentIndex].content.toNode(context)
        : MantleTextNode('');

    final panel = MantleElementNode(
      tag: 'div',
      classes: const ['mantle-tab-panel'],
      attributes: const {'role': 'tabpanel'},
      styles: const {'padding': '16px 0'},
      children: [activeContent],
    );

    return MantleElementNode(
      tag: 'div',
      classes: const ['mantle-tabs-container'],
      children: [headerBar, panel],
      key: key,
    );
  }
}
