import 'dart:async';

import 'binary_semaphore.dart';
import 'lock.dart';

/// A [MultipleWriteSingleReadObject] is a synchronized object.
///
/// If an object is not held by one or more `writers`, then `readers` can access
/// the value of and object (using the [read] method) without any delay, having
/// previously checked the state of the object by reading the value [isLocked].
///
/// If a object is held by one or more `writers`, then `readers` must waiting
/// for the `write` operations to complete using the [wait] method.\
/// After that, a value cad be accessed immediately using the [read] method.
///
/// If an object is held by one or more `readers` and a `write` operation is
/// requested, the `writer` will wait  for all previous `read` and `write`
/// operations.
class MultipleWriteSingleReadObject<T> {
  static const Future<void> Function() _emptyAction = _noop;

  static final Future<void> _void = Future.value();

  final Lock _lock = BinarySemaphore();

  T _value;

  int _writeCount = 0;

  MultipleWriteSingleReadObject(T value) : _value = value;

  bool get isLocked => _writeCount != 0;

  T read() {
    if (_writeCount != 0) {
      throw StateError('Single writer object ($T) is locked');
    }

    return _value;
  }

  Future<void> wait() {
    if (_writeCount == 0) {
      return _void;
    }

    return _lock.lock(_emptyAction);
  }

  Future<void> write(FutureOr<T> Function(T value) action) async {
    await _lock.acquire();
    try {
      _writeCount++;
      _value = await action(_value);
    } finally {
      _writeCount--;
      await _lock.release();
    }
  }

  static Future<void> _noop() {
    return _void;
  }
}
