import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';

/// A [CountingSemaphore] is a synchronization primitive that maintains a
/// counter that represents the number of available permits.
///
/// Acquire:\
/// If the counter is 0, the caller blocks (sleeps) until the count becomes
/// greater than 0.\
/// Otherwise, the counter is decremented, and the caller acquires a permit.
///
/// Release:\
/// If any caller were blocked, one is woken up to acquire permit.\
/// Otherwise, the counter is incremented.
class CountingSemaphore {
  static final Future<bool> _true = Future.value(true);

  static final Future<void> _void = Future.value();

  int _count = 0;

  final int _maxCount;

  final WaitQueue _queue = WaitQueue();

  CountingSemaphore(int initialCount, int maxCount) : _maxCount = maxCount {
    if (maxCount < 0) {
      throw RangeError.range(maxCount, 0, null, 'maxCount');
    }

    if (initialCount < 0 || initialCount > maxCount) {
      throw RangeError.range(initialCount, 0, maxCount, 'initialCount');
    }

    _count = maxCount - initialCount;
  }

  /// Acquires a permit from this semaphore.
  Future<void> acquire() {
    if (_count > 0) {
      _count--;
      return _true;
    }

    return _queue.enqueue();
  }

  /// Releases a permit.
  Future<void> release() {
    if (_queue.isNotEmpty) {
      _queue.dequeue();
      return _void;
    }

    if (_count + 1 > _maxCount) {
      throw StateError("Unmatched call of 'release()()' method");
    }

    _count++;
    return _void;
  }

  /// Tries to acquire a permit from this semaphore and waits until the
  /// specified timeout expires.\
  /// If the semaphore is locked and timeout is zero (or not specified), `false`
  /// is returned.\
  /// If the timeout expires before the semaphore is unlocked, then returns
  /// `false`.\
  /// If permit was acquired, returns `true`.
  @useResult
  Future<bool> tryAcquire(Duration timeout) {
    if (_count > 0) {
      _count--;
      return _true;
    }

    return _queue.enqueue(timeout);
  }
}
