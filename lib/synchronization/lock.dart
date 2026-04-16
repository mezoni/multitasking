import 'dart:async';

import 'package:meta/meta.dart';

/// A [Lock] is an abstract interface that can be used to implement unified
/// mutual-exclusion synchronization primitives.
///
/// Unified mutual-exclusion synchronization primitives are objects with the
/// following members:
///
/// - [acquire]
/// - [release]
/// - [reacquire]
/// - [tryAcquire]
abstract class Lock {
  /// Acquires the `lock`.
  Future<void> acquire();

  /// Acquires the `lock`, then executes the callback function [action], and
  /// then releases the `lock`.
  ///
  /// Parameters:
  ///
  /// - [action]: A callback function that will be executed after the lock is
  /// acquired.
  Future<void> lock(FutureOr<void> Function() action) async {
    await acquire();
    try {
      await action();
    } finally {
      await release();
    }
  }

  /// Reacquires the lock as quickly as possible.
  ///
  /// This method is not recommended for direct use.\
  /// This method is intended exclusively to ensure fair operation of
  /// reacquiring the lock in condition variable in the `wait()` method.
  ///
  /// Typically, when this method is called, the waiter is placed in a queue
  /// with a priority higher than the entrance queue to avoid starvation.
  Future<void> reacquire();

  /// Releases the `lock`.
  Future<void> release();

  /// Tries to acquire the `lock` and returns `true` if the `lock` was acquired
  /// before the [timeout] expires, otherwise the acquisition attempt is
  /// canceled and `false` is returned.
  ///
  /// Parameters:
  ///
  /// - [timeout]: The period of time during which an attempt to acquire the
  /// `lock` will be performed.
  @useResult
  Future<bool> tryAcquire(Duration timeout);

  /// Tries to acquire the `lock` to execute an [action] and returns `true` if
  /// the `lock` was acquired before the [timeout] expires, otherwise the
  /// acquisition attempt is canceled and `false` is returned.
  ///
  /// Parameters:
  ///
  /// - [timeout]: The period of time during which an attempt to acquire the
  /// `lock` will be performed.
  /// - [action]: A callback function that will be executed after the lock is
  /// acquired.
  @useResult
  Future<bool> tryLock(
    Duration timeout,
    FutureOr<void> Function() action,
  ) async {
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
