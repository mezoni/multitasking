import 'dart:async';
import 'dart:collection';

import 'errors.dart';
import 'task.dart';

class TaskZoneInterceptor<TResult> {
  static const _timerCreationThreshold = 100;

  static const _timerListCapacity = 100;

  late final Zone zone;

  final AnyTask Function() _enter;

  bool _isDeactivated = false;

  final void Function(AnyTask previous) _leave;

  final void Function(Object error, StackTrace? stackTrace) _onError;

  final LinkedList<_Node> _timers = LinkedList();

  int _timersCreated = 0;

  TaskZoneInterceptor({
    required AnyTask Function() enter,
    required void Function(AnyTask previous) leave,
    required void Function(Object error, StackTrace? stackTrace) onError,
  })  : _enter = enter,
        _leave = leave,
        _onError = onError {
    final zoneSpecification = ZoneSpecification(
      createPeriodicTimer: _createPeriodicTimer,
      createTimer: _createTimer,
      handleUncaughtError: _handleUncaughtError,
      registerBinaryCallback: _registerBinaryCallback,
      registerCallback: _registerCallback,
      registerUnaryCallback: _registerUnaryCallback,
      run: _run,
      runBinary: _runBinary,
      runUnary: _runUnary,
      scheduleMicrotask: _scheduleMicrotask,
    );

    zone = Zone.root.fork(specification: zoneSpecification);
  }

  void deactivate() {
    _isDeactivated = true;
    _deactivateTimers();
  }

  Timer _createPeriodicTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function(Timer timer) f) {
    if (_timersCreated++ >= _timerCreationThreshold) {
      _timersCreated = 0;
      if (_timers.length >= _timerListCapacity) {
        _removeInactiveTimers();
      }
    }

    if (_isDeactivated) {
      final timer = parent.createPeriodicTimer(zone, duration, (_) {});
      timer.cancel();
      return timer;
    } else {
      void callback(Timer timer) {
        _executeCallback(() => f(timer));
      }

      final timer = parent.createPeriodicTimer(zone, duration, callback);
      _timers.add(_Node(timer));
      return timer;
    }
  }

  Timer _createTimer(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Duration duration,
    void Function() f,
  ) {
    if (_timersCreated++ >= _timerCreationThreshold) {
      _timersCreated = 0;
      if (_timers.length >= _timerListCapacity) {
        _removeInactiveTimers();
      }
    }

    if (_isDeactivated) {
      final timer = parent.createTimer(zone, duration, () {});
      timer.cancel();
      return timer;
    } else {
      void callback() {
        _executeCallback(f);
      }

      final timer = parent.createTimer(zone, duration, callback);
      _timers.add(_Node(timer));
      return timer;
    }
  }

  void _deactivateTimers() {
    if (_timers.isNotEmpty) {
      _Node? node = _timers.first;
      while (node != null) {
        final next = node.next;
        final timer = node.timer;
        if (timer.isActive) {
          timer.cancel();
        }

        node = next;
      }
    }

    _timers.clear();
  }

  void _executeCallback(void Function() f) {
    if (_isDeactivated) {
      return;
    }

    f();
  }

  void _handleUncaughtError(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Object error,
    StackTrace stackTrace,
  ) {
    _onError(error, stackTrace);
  }

  ZoneBinaryCallback<R, T1, T2> _registerBinaryCallback<R, T1, T2>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg1, T2 arg2) f,
  ) {
    R callback(T1 arg1, T2 arg2) {
      throw TaskStoppedError();
    }

    if (_isDeactivated) {
      f = callback;
    }

    return parent.registerBinaryCallback(zone, f);
  }

  ZoneCallback<R> _registerCallback<R>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function() f,
  ) {
    R callback() {
      throw TaskStoppedError();
    }

    if (_isDeactivated) {
      f = callback;
    }

    return parent.registerCallback(zone, f);
  }

  ZoneUnaryCallback<R, T> _registerUnaryCallback<R, T>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T arg) f,
  ) {
    R callback(T arg) {
      throw TaskStoppedError();
    }

    if (_isDeactivated) {
      f = callback;
    }

    return parent.registerUnaryCallback(zone, f);
  }

  void _removeInactiveTimers() {
    if (_timers.isNotEmpty) {
      _Node? node = _timers.first;
      while (node != null) {
        final next = node.next;
        final timer = node.timer;
        if (!timer.isActive) {
          node.unlink();
        }

        node = next;
      }
    }
  }

  R _run<R>(Zone self, ZoneDelegate parent, Zone zone, R Function() f) {
    final previous = _enter();
    late R result;
    try {
      result = parent.run(zone, f);
    } finally {
      _leave(previous);
    }

    return result;
  }

  R _runBinary<R, T1, T2>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg1, T2 arg2) f,
    T1 arg1,
    T2 arg2,
  ) {
    final previous = _enter();
    late R result;
    try {
      result = parent.runBinary(zone, f, arg1, arg2);
    } finally {
      _leave(previous);
    }

    return result;
  }

  R _runUnary<R, T>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T arg) f,
    T arg,
  ) {
    final previous = _enter();
    late R result;
    try {
      if (_isDeactivated) {
        return null as R;
      }

      result = parent.runUnary(zone, f, arg);
    } finally {
      _leave(previous);
    }

    return result;
  }

  void _scheduleMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    void callback() {
      _executeCallback(f);
    }

    return parent.scheduleMicrotask(zone, callback);
  }
}

final class _Node extends LinkedListEntry<_Node> {
  final Timer timer;

  _Node(this.timer);
}
