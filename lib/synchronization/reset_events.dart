import 'dart:async';

import 'package:meta/meta.dart';

import '../src/synchronization/wait_queue.dart';

class AutoResetEvent extends _ResetEvent {
  AutoResetEvent(bool isSet) : super(isSet, EventResetMode.autoReset);
}

enum EventResetMode { autoReset, manualReset }

class ManualResetEvent extends _ResetEvent {
  ManualResetEvent(bool isSet) : super(isSet, EventResetMode.manualReset);
}

class _ResetEvent {
  static final Future<bool> _true = Future.value(true);

  static final Future<void> _void = Future.value();

  final EventResetMode mode;

  final WaitQueue _queue = WaitQueue();

  bool _isSet;

  _ResetEvent(bool isSet, this.mode) : _isSet = isSet;

  bool get isSet => _isSet;

  Future<void> reset() {
    _isSet = false;
    return _void;
  }

  Future<void> set() {
    _isSet = true;
    if (mode == EventResetMode.autoReset) {
      if (_queue.isNotEmpty) {
        _isSet = false;
        _queue.enqueue();
      }
    } else {
      while (_queue.isNotEmpty) {
        _queue.enqueue();
      }
    }

    return _void;
  }

  @useResult
  Future<bool> tryWait(Duration timeout) {
    if (_isSet) {
      if (mode == EventResetMode.autoReset) {
        _isSet = false;
      }

      return _true;
    } else {
      return _queue.enqueue(timeout);
    }
  }

  Future<void> wait() {
    if (_isSet) {
      if (mode == EventResetMode.autoReset) {
        _isSet = false;
      }

      return _void;
    } else {
      return _queue.enqueue();
    }
  }
}
