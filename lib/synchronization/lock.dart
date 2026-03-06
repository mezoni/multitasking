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
