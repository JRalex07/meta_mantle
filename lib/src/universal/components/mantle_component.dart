import '../ir/mantle_node.dart';

/// Context provided to components during build time.
abstract class MantleContext {
  /// Current active path (e.g. `/products/123`).
  String get currentPath;

  /// Route parameters extracted from current path (e.g. `{'id': '123'}`).
  Map<String, String> get pathParameters;

  /// Query parameters extracted from URL (e.g. `{'tab': 'reviews'}`).
  Map<String, String> get queryParameters;

  /// Navigates to target [path].
  void go(String path, {Map<String, String>? queryParameters});

  /// Navigates back if history allows.
  void back();
}

/// Base class for all portable UI components in MetaMantle.
abstract class MantleComponent {
  const MantleComponent({this.key});

  final MantleKey? key;

  MantleNode toNode(MantleContext context);
}

/// A component that does not require mutable local state.
abstract class StatelessMantleComponent extends MantleComponent {
  const StatelessMantleComponent({super.key});

  @override
  MantleNode toNode(MantleContext context) => build(context);

  MantleNode build(MantleContext context);
}

/// A component that has associated mutable state.
abstract class StatefulMantleComponent extends MantleComponent {
  const StatefulMantleComponent({super.key});

  MantleState createState();

  @override
  MantleNode toNode(MantleContext context) {
    final state = createState();
    state._component = this;
    state._context = context;
    state.initState();
    return state.build(context);
  }
}

/// The logic and internal state for a [StatefulMantleComponent].
abstract class MantleState<T extends StatefulMantleComponent> {
  T get component => _component as T;
  late StatefulMantleComponent _component;

  MantleContext get context => _context;
  late MantleContext _context;

  void Function()? _onStateChanged;

  void initState() {}

  void didUpdateComponent(covariant T oldComponent) {}

  void dispose() {}

  void setState(void Function() fn) {
    fn();
    _onStateChanged?.call();
  }

  MantleNode build(MantleContext context);
}
