import 'package:meta/meta.dart';

import '../src/task/task.dart';
import 'counting_semaphore.dart';
import 'synchronizer.dart';

/// A [ReentrantLock]  is a synchronization primitive that works like a mutex.\
/// It blocks execution of all tasks that do not own this lock.\
/// The task that acquired the permit becomes the owner of this lock.\
/// The task owner can enter and exit as long as it holds this lock.
class ReentrantLock implements Synchronizer {
  static final Future<void> _void = Future.value();

  int _count = 0;

  AnyTask? _owner;

  final CountingSemaphore _sem = CountingSemaphore(0, 1);

  @override
  Future<void> acquire() async {
    if (_owner == null) {
      _owner = Task.current;
      _count++;
      await _sem.acquire();
      return;
    }

    if (_owner == Task.current) {
      _count++;
      return;
    }

    await _sem.acquire();
    _owner = Task.current;
    _count++;
  }

  @override
  Future<void> release() {
    if (_owner == null) {
      throw StateError(
          'Attempting to release a reentrant lock that is unowned');
    }

    if (_owner != Task.current) {
      throw StateError(
          'Attempting to release a reentrant lock that is owned by a different task');
    }

    if (--_count > 0) {
      return _void;
    }

    _owner = null;
    return _sem.release();
  }

  @override
  @useResult
  Future<bool> tryAcquire(Duration timeout) async {
    if (_owner == null) {
      final isSuccess = await _sem.tryAcquire(timeout);
      if (isSuccess) {
        _owner = Task.current;
        _count++;
        return true;
      }

      return false;
    }

    if (_owner == Task.current) {
      _count++;
      return true;
    }

    final isSuccess = await _sem.tryAcquire(timeout);
    if (isSuccess) {
      _owner = Task.current;
      _count++;
    }

    return isSuccess;
  }
}
