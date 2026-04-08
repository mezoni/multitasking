import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';
import 'lock.dart';

/// A [ConditionVariable] is a synchronization primitive  that allows to wait
/// for a particular condition to become `true` before proceeding.\
/// It is always used in conjunction with a locking to safely manage access to
/// the shared data and prevent race conditions.
class ConditionVariable {
  static final Stopwatch _watch = Stopwatch()..start();

  static final Future<void> _void = Future.value();

  final Lock lock;

  final WaitQueue _queue = WaitQueue();

  ConditionVariable(this.lock);

  /// Removes an element from the wait queue and waits for the lock to be
  /// acquired.\
  /// After the locks acquired, schedules the action specified in the removed
  /// from the queue element to run.
  Future<void> notify() {
    if (_queue.isNotEmpty) {
      _queue.dequeue();
    }

    return _void;
  }

  /// Removes all elements from the wait queue and waits for the lock to be
  /// acquired for each element separately.\
  /// After the locks acquired, schedules the actions specified in the removed
  /// from the queue elements to run.
  Future<void> notifyAll() {
    while (_queue.isNotEmpty) {
      _queue.dequeue();
    }

    return _void;
  }

  /// Releases the lock and waits for a notification.\
  /// Upon receiving the notification, the lock will be reacquired. Accordingly,
  /// upon exiting the method, the locked code will be entered.
  ///
  /// Returns `true` if the timeout has not expired; otherwise, returns `false`.
  @useResult
  Future<bool> tryWait(Duration timeout) async {
    final started = _watch.elapsedMicroseconds;
    if (timeout.isNegative) {
      throw ArgumentError.value(timeout, 'timeout', 'Must not be negative');
    }

    await lock.release();
    await _queue.enqueue();
    await lock.reacquire();
    return _watch.elapsedMicroseconds - started <= timeout.inMicroseconds;
  }

  /// Releases the lock and waits for a notification.\
  /// Upon receiving the notification, the lock will be reacquired. Accordingly,
  /// upon exiting the method, the locked code will be entered.
  Future<void> wait() async {
    await lock.release();
    await _queue.enqueue();
    return lock.reacquire();
  }
}
