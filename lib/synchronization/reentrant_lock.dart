import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';
import 'lock.dart';

/// A [ReentrantLock] is a synchronization primitive that works like a mutex.\
/// It blocks execution of all zones that do not own this lock.\
/// The zone that acquired the permit becomes the owner of this lock.\
/// The zone owner can enter and exit as long as it holds this lock.
class ReentrantLock extends Lock {
  static final Future<void> _void = Future.value();

  int _count = 0;

  Zone? _owner;

  final WaitQueue _queue = WaitQueue();

  @override
  Future<void> acquire() async {
    if (_owner == null) {
      _owner = Zone.current;
      _count++;
      return;
    }

    if (_owner == Zone.current) {
      _count++;
      return;
    }

    await _queue.enqueue();
    _owner = Zone.current;
    _count++;
    return;
  }

  @override
  Future<void> release() {
    if (_owner == null) {
      throw StateError('Attempting to release a lock that is unowned');
    }

    if (_owner != Zone.current) {
      throw StateError(
          'Attempting to release a lock that is owned by a different zone');
    }

    if (--_count > 0) {
      return _void;
    }

    _owner = null;
    if (_queue.isNotEmpty) {
      _queue.dequeue();
    }

    return _void;
  }

  @override
  @useResult
  Future<bool> tryAcquire(Duration timeout) async {
    if (_owner == null) {
      _owner = Zone.current;
      _count++;
      return true;
    }

    if (_owner == Zone.current) {
      _count++;
      return true;
    }

    final isSuccess = await _queue.enqueue(timeout);
    if (isSuccess) {
      _owner = Zone.current;
      _count++;
    }

    return isSuccess;
  }
}
