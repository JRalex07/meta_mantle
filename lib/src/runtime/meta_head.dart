import 'package:flutter/widgets.dart';

import '../models/metadata.dart';
import 'runtime_coordinator.dart';

/// Applies [metadata] while this widget is mounted.
///
/// The most recently activated [MetaHead] scope wins. On deactivation or
/// disposal, the previously active scope is restored. Put one around each page.
class MetaHead extends StatefulWidget {
  const MetaHead({
    required this.metadata,
    required this.child,
    this.active = true,
    super.key,
  });

  final WebMetadata metadata;
  final Widget child;

  /// Whether this page currently owns the active metadata scope. Set this to
  /// false for retained/offstage pages such as inactive tab navigators.
  final bool active;

  @override
  State<MetaHead> createState() => _MetaHeadState();
}

class _MetaHeadState extends State<MetaHead> {
  final Object _owner = Object();

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      RuntimeCoordinator.instance.activate(_owner, widget.metadata);
    }
  }

  @override
  void didUpdateWidget(covariant MetaHead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      RuntimeCoordinator.instance.remove(_owner);
    } else if (!oldWidget.active && widget.active) {
      RuntimeCoordinator.instance.activate(_owner, widget.metadata);
    } else if (widget.active && oldWidget.metadata != widget.metadata) {
      RuntimeCoordinator.instance.update(_owner, widget.metadata);
    }
  }

  @override
  void dispose() {
    RuntimeCoordinator.instance.remove(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Backward compatibility alias for [MetaHead].
typedef WebHead = MetaHead;
