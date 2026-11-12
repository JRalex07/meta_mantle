/// Abstract cross-platform event passed to portable Mantle event callbacks.
class MantleEvent {
  const MantleEvent({
    this.type = 'generic',
    this.value,
    this.targetId,
  });

  final String type;
  final Object? value;
  final String? targetId;
}

typedef MantleVoidCallback = void Function();
typedef MantleValueCallback<T> = void Function(T value);
typedef MantleEventCallback = void Function(MantleEvent event);
