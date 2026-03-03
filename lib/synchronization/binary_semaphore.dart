import 'dart:async';

import 'package:meta/meta.dart';

import 'counting_semaphore.dart';
import 'synchronizer.dart';

/// A [BinarySemaphore] is a synchronization primitive with an integer value
/// restricted to 0 or 1, representing locked (0) or unlocked (1) states.
class BinarySemaphore implements Synchronizer {
  final CountingSemaphore _lock = CountingSemaphore(0, 1);

  /// Acquires a permit from this semaphore.
  @override
  Future<void> acquire() {
    return _lock.acquire();
  }

  /// Releases a permit.
  @override
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
  @override
  @useResult
  Future<bool> tryAcquire(Duration timeout) {
    return _lock.tryAcquire(timeout);
  }
}
