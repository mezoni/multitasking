import 'dart:async';

class Progress<T> {
  final FutureOr<void> Function(T) _callback;

  final Zone _zone;

  Progress(FutureOr<void> Function(T) callback)
      : _callback = callback,
        _zone = Zone.current;

  void report(T event) {
    _zone.scheduleMicrotask(() async {
      await _callback(event);
    });
  }
}
