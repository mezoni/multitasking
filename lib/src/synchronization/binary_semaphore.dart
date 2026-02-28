import 'dart:async';

import 'package:meta/meta.dart';

import 'counting_semaphore.dart';

/// A [BinarySemaphore] is a synchronization primitive with an integer value
/// restricted to 0 or 1, representing locked (0) or unlocked (1) states.
///
/// Unlike a mutex, a semaphore is a counting-based synchronizer.\
/// If a semaphore is locked, it will be locked even for the current task.
///
/// If a mutex is locked by a task, it will not block this task. It will
/// count the number of times it is entered and leaved by task before
/// releasing.
class BinarySemaphore {
  final CountingSemaphore _lock = CountingSemaphore(0, maxCount: 1);

  /// Acquires a permit from this semaphore.
  Future<void> acquire() {
    return _lock.acquire();
  }

  /// Releases a permit.
  Future<void> release() {
    return _lock.release();
  }

  /// Tries to acquire a permit from this semaphore and waits until the
  /// specified timeout expires.\
  /// If the semaphore is locked and timeout is zero (or not specified), `false`
  /// is returned.\
  /// If the timeout expires before the semaphore is unlocked, then returns
  /// `false`.\
  /// If permit was acquired, returns `true`.
  @useResult
  Future<bool> tryAcquire([Duration? timeout]) {
    return _lock.tryAcquire(timeout);
  }
}
