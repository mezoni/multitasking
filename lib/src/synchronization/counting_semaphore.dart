import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'time_utils.dart';

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
  static const _maxInt = 0x7fffffffffffffff;

  int _count = 0;

  final int _maxCount;

  final LinkedList<_Node> _queue = LinkedList();

  CountingSemaphore(int initialCount, {int maxCount = _maxInt})
      : _maxCount = maxCount {
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
      return Future.value();
    }

    final node = _Node();
    _queue.add(node);
    final completer = node.completer;
    return completer.future;
  }

  /// Releases a permit.
  Future<void> release() {
    int? now;
    while (_queue.isNotEmpty) {
      final node = _queue.first;
      node.unlink();
      final completer = node.completer;
      final timer = node.timer;
      if (timer == null) {
        completer.complete(true);
        return Future.value();
      }

      timer.cancel();
      now ??= TimeUtils.elapsedMicroseconds;
      final timeout = node.timeout!;
      if (now - node.started >= timeout.inMicroseconds) {
        completer.complete(false);
      }
    }

    if (_count + 1 > _maxCount) {
      throw StateError('Unmatched call of \'release()()\' method');
    }

    _count++;
    return Future.value();
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
    if (timeout != null) {
      if (timeout.isNegative) {
        throw ArgumentError.value(
            timeout, 'timeout', 'Timeout must not be negative');
      }
    } else {
      timeout = const Duration(seconds: 0);
    }

    if (_count > 0) {
      _count--;
      return Future.value(true);
    }

    if (timeout.inMicroseconds == 0) {
      return Future.value(false);
    }

    final node = _Node();
    _queue.add(node);
    node.timer = Timer(timeout, () {
      node.unlink();
      node.timer = null;
      node.timeout = null;
      final completer = node.completer;
      completer.complete(false);
    });

    node.started = TimeUtils.elapsedMicroseconds;
    final completer = node.completer;
    return completer.future;
  }
}

base class _Node extends LinkedListEntry<_Node> {
  final completer = Completer<bool>();

  int started = 0;

  Timer? timer;

  Duration? timeout;
}
