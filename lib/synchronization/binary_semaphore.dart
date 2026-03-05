import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';
import 'lock.dart';

/// A [BinarySemaphore] is a synchronization primitive with an integer value
/// restricted to 0 or 1, representing locked (0) or unlocked (1) states.
class BinarySemaphore extends Lock {
  static final Future<bool> _true = Future.value(true);

  static final Future<void> _void = Future.value();

  bool _isLocked = false;

  final WaitQueue _waitQueue = WaitQueue();

  /// Acquires a permit from this semaphore.
  @override
  Future<void> acquire() {
    if (!_isLocked) {
      _isLocked = true;
      return _void;
    }

    return _waitQueue.enqueue();
  }

  /// Releases a permit.
  @override
  Future<void> release() {
    if (!_isLocked) {
      throw StateError('Unmatched call of \'release()()\' method');
    }

    if (!_waitQueue.dequeue()) {
      _isLocked = false;
    }

    return _void;
  }

  /// Tries to acquire a permit from this semaphore and waits until the
  /// specified timeout expires.\
  /// If the semaphore is locked and timeout is zero (or not specified), `false`
  /// is returned.\
  /// If the timeout expires before the semaphore is unlocked, then returns
  /// `false`.\
  /// If permit was acquired, returns `true`.
  @override
  @useResult
  Future<bool> tryAcquire(Duration timeout) {
    if (timeout.isNegative) {
      throw ArgumentError.value(
          timeout, 'timeout', 'Timeout must not be negative');
    }

    if (!_isLocked) {
      _isLocked = true;
      return _true;
    }

    return _waitQueue.enqueue(timeout);
  }
}
