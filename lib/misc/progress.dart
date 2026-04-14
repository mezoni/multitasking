import 'dart:async';

/// The [Progress] class is intended for monitoring the execution of operations
/// where progress can be measured quantitatively.
class Progress<T> {
  final FutureOr<void> Function(T) _callback;

  final Zone _zone;

  /// Creates an instance of [Progress].
  ///
  /// Parameters:
  ///
  /// - [callback]: A callback function that will be called when the [report]
  /// method is called.
  ///
  /// The callback function can be defined with any required parameter type.\
  /// The function [report] must be called with the same parameter type.
  Progress(FutureOr<void> Function(T value) callback)
      : _callback = callback,
        _zone = Zone.current;

  /// Notifies the the reporting function.
  void report(T value) {
    _zone.scheduleMicrotask(() async {
      await _callback(value);
    });
  }
}
