import 'dart:async';

import 'task.dart';

class TaskZoneInterceptor<TResult> {
  late final Zone zone;

  final AnyTask Function() _enter;

  final void Function(AnyTask previous) _leave;

  final void Function(Object error, StackTrace? stackTrace) _onError;

  TaskZoneInterceptor({
    required AnyTask Function() enter,
    required void Function(AnyTask previous) leave,
    required void Function(Object error, StackTrace? stackTrace) onError,
  })  : _enter = enter,
        _leave = leave,
        _onError = onError {
    final zoneSpecification = ZoneSpecification(
      handleUncaughtError: _handleUncaughtError,
      run: _run,
      runBinary: _runBinary,
      runUnary: _runUnary,
    );

    zone = Zone.root.fork(specification: zoneSpecification);
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
      result = parent.runUnary(zone, f, arg);
    } finally {
      _leave(previous);
    }

    return result;
  }
}
