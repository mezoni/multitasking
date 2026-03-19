import 'dart:async';

import 'package:meta/meta.dart';

abstract class Lock {
  Future<void> acquire();

  Future<void> lock(FutureOr<void> Function() action) async {
    await acquire();
    try {
      await action();
    } finally {
      await release();
    }
  }

  /// Reacquires the lock as quickly as possible.\
  /// This method is not recommended for direct use.\
  /// This method is intended exclusively to ensure fair operation of
  /// reacquiring the lock in condition variable in the `wait()` method.
  ///
  /// Typically, when this method is called, the waiter is placed in a queue
  /// with a priority higher than the entrance queue to avoid starvation.
  Future<void> reacquire();

  Future<void> release();

  @useResult
  Future<bool> tryAcquire(Duration timeout);

  @useResult
  Future<bool> tryLock(
      Duration timeout, FutureOr<void> Function() action) async {
    final isSuccess = await tryAcquire(timeout);
    if (isSuccess) {
      try {
        await action();
      } finally {
        await release();
      }
    }

    return isSuccess;
  }
}
