import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';
import 'lock.dart';

/// A [ConditionVariable] is a synchronization primitive  that allows to wait
/// for a particular condition to become `true` before proceeding.\
/// It is always used in conjunction with a locking to safely manage access to
/// the shared data and prevent race conditions.
class ConditionVariable {
  static final Future<void> _void = Future.value();

  final Lock lock;

  final WaitQueue _queue = WaitQueue();

  ConditionVariable(this.lock);

  Future<void> notify() {
    if (_queue.isNotEmpty) {
      final awaiter = _queue.removeFirst();
      lock.acquire().then((_) {
        awaiter.complete(true);
      });
    }

    return _void;
  }

  Future<void> notifyAll() {
    while (_queue.isNotEmpty) {
      final awaiter = _queue.removeFirst();
      lock.acquire().then((_) {
        awaiter.complete(true);
      });
    }

    return _void;
  }

  @useResult
  Future<bool> tryWait(Duration timeout) async {
    await lock.release();
    final waiter = _queue.enqueue(timeout);
    return await waiter;
  }

  Future<void> wait() async {
    await lock.release();
    final waiter = _queue.enqueue();
    await waiter;
  }
}
