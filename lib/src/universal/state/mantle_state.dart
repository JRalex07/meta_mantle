import 'dart:async';

import '../components/mantle_component.dart';
import '../ir/mantle_node.dart';

/// Contract for objects that need lifecycle disposal.
abstract class MantleDisposable {
  void dispose();
}

/// An observable value that notifies registered listeners when changed.
class MantleObservable<T> implements MantleDisposable {
  MantleObservable(this._value);

  T _value;
  final Set<void Function(T value)> _listeners = {};
  bool _disposed = false;

  /// The current value held by this observable.
  T get value => _value;

  set value(T newValue) {
    if (_disposed) return;
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }

  /// Adds a listener callback invoked whenever [value] changes.
  void addListener(void Function(T value) listener) {
    if (!_disposed) {
      _listeners.add(listener);
    }
  }

  /// Removes a previously registered [listener].
  void removeListener(void Function(T value) listener) {
    _listeners.remove(listener);
  }

  /// Notifies all registered listeners of the current [value].
  void notifyListeners() {
    if (_disposed) return;
    final snapshot = List<void Function(T value)>.from(_listeners);
    for (final listener in snapshot) {
      listener(_value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

/// Observable state store supporting key-value state management across components.
class MantleStore implements MantleDisposable {
  MantleStore([Map<String, Object?>? initial]) {
    if (initial != null) {
      _state.addAll(initial);
    }
  }

  final Map<String, Object?> _state = {};
  final Map<String, Set<void Function(Object? value)>> _keyListeners = {};
  final Set<void Function()> _globalListeners = {};
  bool _disposed = false;

  /// Retrieves value for [key], or null if unset.
  T? get<T>(String key) => _state[key] as T?;

  /// Sets [value] for [key] and notifies affected listeners.
  void set<T>(String key, T value) {
    if (_disposed) return;
    if (_state[key] != value) {
      _state[key] = value;
      final listeners = _keyListeners[key];
      if (listeners != null) {
        for (final listener in List.from(listeners)) {
          listener(value);
        }
      }
      for (final listener in List.from(_globalListeners)) {
        listener();
      }
    }
  }

  /// Subscribes to changes for a specific [key].
  void watch(String key, void Function(Object? value) callback) {
    if (_disposed) return;
    _keyListeners.putIfAbsent(key, () => {}).add(callback);
  }

  /// Unsubscribes a callback for [key].
  void unwatch(String key, void Function(Object? value) callback) {
    _keyListeners[key]?.remove(callback);
  }

  /// Subscribes to any mutation in the store.
  void addListener(void Function() listener) {
    if (!_disposed) _globalListeners.add(listener);
  }

  /// Unsubscribes global listener.
  void removeListener(void Function() listener) {
    _globalListeners.remove(listener);
  }

  @override
  void dispose() {
    _disposed = true;
    _state.clear();
    _keyListeners.clear();
    _globalListeners.clear();
  }
}

/// A reactive component that rebuilds when a [MantleObservable] changes.
class MantleBuilder<T> extends StatefulMantleComponent {
  const MantleBuilder({
    required this.observable,
    required this.builder,
    super.key,
  });

  final MantleObservable<T> observable;
  final MantleComponent Function(MantleContext context, T value) builder;

  @override
  MantleState<MantleBuilder<T>> createState() => _MantleBuilderState<T>();
}

class _MantleBuilderState<T> extends MantleState<MantleBuilder<T>> {
  late T _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = component.observable.value;
    component.observable.addListener(_onValueChanged);
  }

  void _onValueChanged(T newValue) {
    setState(() {
      _currentValue = newValue;
    });
  }

  @override
  void didUpdateComponent(covariant MantleBuilder<T> oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.observable != component.observable) {
      oldComponent.observable.removeListener(_onValueChanged);
      _currentValue = component.observable.value;
      component.observable.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    component.observable.removeListener(_onValueChanged);
    super.dispose();
  }

  @override
  MantleNode build(MantleContext context) {
    return component.builder(context, _currentValue).toNode(context);
  }
}

/// Asynchronous state wrapper for Futures.
class MantleAsyncSnapshot<T> {
  const MantleAsyncSnapshot({
    this.data,
    this.error,
    this.isLoading = false,
  });

  final T? data;
  final Object? error;
  final bool isLoading;

  bool get hasData => data != null;
  bool get hasError => error != null;
}

/// A component that renders based on the latest state of a [Future].
class MantleFutureBuilder<T> extends StatefulMantleComponent {
  const MantleFutureBuilder({
    required this.future,
    required this.builder,
    this.initialData,
    super.key,
  });

  final Future<T> future;
  final MantleComponent Function(
      MantleContext context, MantleAsyncSnapshot<T> snapshot) builder;
  final T? initialData;

  @override
  MantleState<MantleFutureBuilder<T>> createState() =>
      _MantleFutureBuilderState<T>();
}

class _MantleFutureBuilderState<T> extends MantleState<MantleFutureBuilder<T>> {
  late MantleAsyncSnapshot<T> _snapshot;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _snapshot = MantleAsyncSnapshot<T>(
      data: component.initialData,
      isLoading: true,
    );
    _subscribe();
  }

  void _subscribe() {
    component.future.then((data) {
      if (!_cancelled) {
        setState(() {
          _snapshot = MantleAsyncSnapshot<T>(data: data, isLoading: false);
        });
      }
    }).catchError((err) {
      if (!_cancelled) {
        setState(() {
          _snapshot = MantleAsyncSnapshot<T>(error: err, isLoading: false);
        });
      }
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  MantleNode build(MantleContext context) {
    return component.builder(context, _snapshot).toNode(context);
  }
}
