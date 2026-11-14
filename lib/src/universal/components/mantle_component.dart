import '../ir/mantle_node.dart';

/// Registry retaining and managing lifecycle for [MantleState] instances.
class MantleStateRegistry {
  final Map<String, MantleState> _states = {};
  final Map<Type, int> _typeCounters = {};
  final Expando<String> _instanceKeys = Expando<String>();
  final Set<String> _visitedKeysInCurrentPass = {};
  void Function()? onNeedsRebuild;

  /// Resets per-pass positional counters at the start of a build traversal.
  void beginBuildPass() {
    _typeCounters.clear();
    _visitedKeysInCurrentPass.clear();
  }

  /// Concludes a build pass and disposes any states not mounted/visited during this pass.
  void endBuildPass() {
    final unvisited = _states.keys.toSet().difference(
      _visitedKeysInCurrentPass,
    );
    for (final key in unvisited) {
      final state = _states.remove(key);
      if (state != null) {
        state._mounted = false;
        state.dispose();
      }
    }
    _visitedKeysInCurrentPass.clear();
  }

  /// Retrieves an existing [MantleState] by its state ID if registered.
  MantleState? getState(String stateId) => _states[stateId];

  /// Retrieves an existing [MantleState] or instantiates and mounts a new one.
  MantleState getOrCreateState(
    StatefulMantleComponent component,
    MantleContext context,
  ) {
    final String stateId;
    if (component.key != null) {
      stateId = 'k_${component.key!.value}';
    } else {
      final existingKey = _instanceKeys[component];
      if (existingKey != null) {
        stateId = existingKey;
      } else {
        final counter = (_typeCounters[component.runtimeType] ?? 0) + 1;
        _typeCounters[component.runtimeType] = counter;
        stateId = 't_${component.runtimeType}_$counter';
        _instanceKeys[component] = stateId;
      }
    }

    _visitedKeysInCurrentPass.add(stateId);

    if (_states.containsKey(stateId)) {
      final existingState = _states[stateId]!;
      final oldComponent = existingState._component;
      existingState._component = component;
      existingState._context = context;
      existingState.didUpdateComponent(oldComponent);
      return existingState;
    }

    final newState = component.createState();
    newState._component = component;
    newState._context = context;
    newState._stateId = stateId;
    newState._mounted = true;
    newState._onStateChanged = () {
      onNeedsRebuild?.call();
    };
    _states[stateId] = newState;
    newState.initState();
    return newState;
  }

  /// Disposes all registered states and clears the registry.
  void dispose() {
    for (final state in _states.values) {
      state._mounted = false;
      state.dispose();
    }
    _states.clear();
    _typeCounters.clear();
    _visitedKeysInCurrentPass.clear();
  }
}

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

  /// State registry for preserving component states across render passes.
  MantleStateRegistry get stateRegistry;
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
    final state = context.stateRegistry.getOrCreateState(this, context);
    return state.build(context);
  }
}

/// The logic and internal state for a [StatefulMantleComponent].
abstract class MantleState<T extends StatefulMantleComponent> {
  T get component => _component as T;
  late StatefulMantleComponent _component;

  MantleContext get context => _context;
  late MantleContext _context;

  String? get stateId => _stateId;
  String? _stateId;
  bool get mounted => _mounted;
  bool _mounted = false;

  void Function()? _onStateChanged;

  void initState() {}

  void didUpdateComponent(covariant T oldComponent) {}

  void dispose() {
    _mounted = false;
  }

  void setState(void Function() fn) {
    if (!_mounted) return;
    fn();
    _onStateChanged?.call();
  }

  MantleNode build(MantleContext context);
}
