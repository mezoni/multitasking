import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';

/// A [AutoResetEvent] is a synchronization primitive that is used to manage
/// signaling.\
/// When an event is in a `signaled` state, any calls to the [wait] method will
/// not block execution of the calling code.\
/// When an event is in a `non-signaled` state, any calls to the [wait] method
/// will block execution of the calling code.
///
/// After unblocking one calling code, it automatically switches to the
/// `non-signaled` state.
class AutoResetEvent extends _ResetEvent {
  static final Future<bool> _true = Future.value(true);

  /// Creates an instance of [AutoResetEvent].
  ///
  /// Parameters:
  ///
  /// - [isSet]: The initial state of the event (`signaled` or `non-signaled`).
  AutoResetEvent(super.isSet);

  /// Switches an event in the `signaled` state, allowing a single waiting code
  /// to continue executing.\
  /// If there is no waiting code, the event remains in `signaled` state until
  /// the [wait] method is called.
  Future<void> set() {
    _isSet = true;
    if (_queue.isNotEmpty) {
      _isSet = false;
      _queue.dequeue();
    }

    return _ResetEvent._void;
  }

  /// Trying to wait for the `signaled` state and returns `true` if the event
  /// was signaled before the [timeout] expires, otherwise the wait attempt is
  /// canceled and `false` is returned.
  ///
  /// Parameters:
  ///
  /// - [timeout]: The period of time during which an attempt to wait for the
  /// `signaled` state  will be performed.
  @useResult
  Future<bool> tryWait(Duration timeout) {
    if (_isSet) {
      _isSet = false;
      return _true;
    } else {
      return _queue.enqueue(timeout);
    }
  }

  /// Blocks the calling code until the event switches the `signaled` state.\
  /// If the event is already in the `signaled` state, the calling code
  /// continues execution, and the event is immediately switched to the
  /// `non-signaled` state.
  Future<void> wait() {
    if (_isSet) {
      _isSet = false;
      return _ResetEvent._void;
    } else {
      return _queue.enqueue();
    }
  }
}

/// A [ManualResetEvent] is a synchronization primitive that is used to manage
/// signaling.\
/// When an event is in a `signaled` state, any calls to the [wait] method will
/// not block execution of the calling code.\
/// When an event is in a `non-signaled` state, any calls to the [wait] method
/// will block execution of the calling code.
///
/// Once switched to the `signaled` state, the event remains in the `signaled`
/// state until it is manually [reset].
class ManualResetEvent extends _ResetEvent {
  /// Creates an instance of [ManualResetEvent].
  ///
  /// Parameters:
  ///
  /// - [isSet]: The initial state of the event (`signaled` or `non-signaled`).
  ManualResetEvent(super.isSet);

  /// Switches the event into the `signaled` state.\
  /// Any subsequent calls to the [wait] method will not block execution of the
  /// calling code.
  Future<void> set() {
    _isSet = true;
    while (_queue.isNotEmpty) {
      _queue.dequeue();
    }

    return _ResetEvent._void;
  }

  /// Trying to wait for the `signaled` state and returns `true` if the event
  /// was signaled before the [timeout] expires, otherwise the wait attempt is
  /// canceled and `false` is returned.
  ///
  /// Parameters:
  ///
  /// - [timeout]: The period of time during which an attempt to wait for the
  /// `signaled` state  will be performed.
  @useResult
  Future<bool> tryWait(Duration timeout) {
    return _queue.enqueue(timeout);
  }

  /// The calling code calls this method to wait for the signal.\
  /// If the event is in the `non-signaled` state, the calling code blocks.\
  /// If the event is in the `signaled` state, the calling code continues
  /// execution.
  Future<void> wait() {
    if (_isSet) {
      return _ResetEvent._void;
    }

    return _queue.enqueue();
  }
}

class _ResetEvent {
  static final Future<void> _void = Future.value();

  final WaitQueue _queue = WaitQueue();

  bool _isSet;

  _ResetEvent(bool isSet) : _isSet = isSet;

  bool get isSet => _isSet;

  /// Switches the event back to the `non-signaled` state.\
  /// All subsequent calls to the [wait] method will block the calling code.
  Future<void> reset() {
    _isSet = false;
    return _void;
  }
}
