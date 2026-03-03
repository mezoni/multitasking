import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';
import 'binary_semaphore.dart';

/// A [ConditionVariable] is a synchronization primitive  that allows to wait
/// for a particular condition to become `true` before proceeding.\
/// It is always used in conjunction with a locking to safely manage access to
/// the shared data and prevent race conditions.
class ConditionVariable {
  static final Future<void> _void = Future.value();

  final BinarySemaphore lock;

  final WaitQueue _queue = WaitQueue();

  ConditionVariable(this.lock);

  Future<void> notify() {
    _queue.dequeue();
    return _void;
  }

  Future<void> notifyAll() {
    while (_queue.dequeue()) {}
    return _void;
  }

  @useResult
  Future<bool> tryWait(Duration timeout) async {
    final waiter = _queue.enqueue(timeout);
    await lock.release();
    final result = await waiter;
    await lock.acquire();
    return result;
  }

  Future<void> wait() async {
    final waiter = _queue.enqueue();
    await lock.release();
    await waiter;
    return lock.acquire();
  }
}
