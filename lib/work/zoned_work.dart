import 'dart:async';

import '../multitasking.dart';
import 'work.dart';

/// A [ZonedWork] is an operation for executing a computation inside the [Zone]
/// container with the possibility of externally controlled termination.
///
/// ⚠️ Warning:\
/// When using [ZonedWork], the following limitation should be taken into
/// account.\
/// Because [ZonedWork] runs in a separate zone with its own uncaught errors
/// handler [ZoneSpecification.handleUncaughtError] due to limitations of the
/// Dart SDK, when using such a handler, in some cases, errors from the parent
/// zone may not leave the parent zone and may lead to the fact that it will be
/// physically impossible to catch them (and `shut down` the [Zone] correctly).
///
/// More detailed information can be found here:
///
/// - https://github.com/dart-lang/sdk/issues/49457
/// - https://github.com/dart-lang/sdk/issues/63353
class ZonedWork<T> implements Work<T> {
  final FutureOr<T> Function() _computation;

  final _completer = Completer<void>();

  bool _isStarted = false;

  bool _isTerminationRequested = false;

  Object? _error;

  final Set<Timer> _periodicTimers = {};

  StackTrace? _stackTrace;

  final Set<Timer> _timers = {};

  final CancellationToken? _token;

  late final Zone _zone;

  /// Creates an instance of [ZonedWork].
  ///
  /// Parameters:
  ///
  /// - [computation]: A callback that represents a computation.
  /// - [token]: Cancellation token used for canceling the execution of
  /// computation.
  ///
  /// If the [token] parameter is specified, it can be retrieved in the
  /// computation] body by calling [Task.token].\
  /// Token-based cancellation is a very flexible cancellation method,
  /// implemented solely based on the cancellation request processing logic.
  ZonedWork(
    FutureOr<T> Function() computation, {
    CancellationToken? token,
  })  : _computation = computation,
        _token = token {
    _zone = Zone.current.fork(
      specification: ZoneSpecification(
        createPeriodicTimer: _createPeriodicTimer,
        createTimer: _createTimer,
        handleUncaughtError: _handleUncaughtError,
        run: _handleRun,
        runBinary: _handleRunBinary,
        runUnary: _handleRunUnary,
        scheduleMicrotask: _scheduleMicrotask,
      ),
    );
  }

  bool get _isDeactivated => _isTerminationRequested || _error != null;

  @override
  Future<T> run() async {
    if (_isStarted) {
      throw StateError('The computation can be run only once');
    }

    _isStarted = true;
    if (_isTerminationRequested) {
      throw CancellationException();
    }

    if (_token != null) {
      _token!.throwIfCanceled();
    }

    var hasResult = false;
    T? result;
    unawaited(() async {
      try {
        await Future<void>.delayed(Duration.zero);
        result = await _zone.run(() {
          return Task.run(token: _token, _computation);
        });
        hasResult = true;
      } catch (e, s) {
        if (_error == null) {
          _error = e;
          _stackTrace = s;
        }
      }

      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }());

    await _completer.future;
    if (_isTerminationRequested) {
      throw CancellationException();
    } else if (_error != null) {
      Error.throwWithStackTrace(_error!, _stackTrace ?? StackTrace.empty);
    } else if (hasResult) {
      return result as T;
    } else {
      throw StateError('Computation ended without result');
    }
  }

  @override
  void terminate({bool force = false}) {
    if (_isTerminationRequested) {
      return;
    }

    _isTerminationRequested = true;
    _terminate();
  }

  Timer _createPeriodicTimer(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Duration period,
    void Function(Timer timer) f,
  ) {
    void callback(Timer timer) {
      if (!_isDeactivated) {
        f(timer);
      }
    }

    void onCancel(Timer timer) {
      _periodicTimers.remove(timer);
    }

    final timer = parent.createPeriodicTimer(zone, period, callback);
    return _Timer(timer, onCancel);
  }

  Timer _createTimer(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Duration period,
    void Function() f,
  ) {
    Timer? timer;
    void callback() {
      _timers.remove(timer!);
      if (!_isDeactivated) {
        f();
      }
    }

    timer = parent.createTimer(zone, period, callback);
    return timer;
  }

  R _handleRun<R>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function() f,
  ) {
    R callback() {
      if (_isDeactivated && _isNullable<R>()) {
        return null as R;
      }

      return f();
    }

    return parent.run(zone, callback);
  }

  R _handleRunBinary<R, T1, T2>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg1, T2 arg2) f,
    T1 arg1,
    T2 arg2,
  ) {
    R callback(T1 arg1, T2 arg2) {
      if (_isDeactivated && _isNullable<R>()) {
        return null as R;
      }

      return f(arg1, arg2);
    }

    return parent.runBinary(zone, callback, arg1, arg2);
  }

  R _handleRunUnary<R, T1>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg) f,
    T1 arg,
  ) {
    R callback(T1 arg1) {
      if (_isDeactivated && _isNullable<R>()) {
        return null as R;
      }

      return f(arg1);
    }

    return parent.runUnary(zone, callback, arg);
  }

  void _handleUncaughtError(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_error == null) {
      _error = error;
      _stackTrace = stackTrace;
      _terminate();
    }
  }

  void _scheduleMicrotask(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    void Function() f,
  ) {
    void callback() {
      if (!_isDeactivated) {
        f();
      }
    }

    if (!_isDeactivated) {
      parent.scheduleMicrotask(zone, callback);
    }
  }

  void _terminate() {
    if (_timers.isNotEmpty) {
      for (final timer in _timers) {
        timer.cancel();
      }
    }

    if (_periodicTimers.isNotEmpty) {
      for (final timer in _periodicTimers) {
        timer.cancel();
      }
    }

    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Creates an instance of [ZonedWork].
  ///
  /// Parameters:
  ///
  /// - [argument]: Argument to pass to the [computation] function.
  /// - [computation]: A function that represents a computation.
  /// - [token]: Cancellation token used for canceling the execution of
  /// computation.
  ///
  /// If the [token] parameter is specified, it can be retrieved in the
  /// computation] body by calling [Task.token].\
  /// Token-based cancellation is a very flexible cancellation method,
  /// implemented solely based on the cancellation request processing logic.
  static ZonedWork<R> withArgument<T, R>(
    T argument,
    FutureOr<R> Function(T arg) computation, {
    CancellationToken? token,
  }) {
    return ZonedWork(() => computation(argument), token: token);
  }

  static bool _isNullable<T>() => null is T;
}

class _Timer implements Timer {
  final void Function(Timer timer) _onCancel;

  final Timer _timer;

  _Timer(this._timer, this._onCancel);

  @override
  bool get isActive => _timer.isActive;

  @override
  int get tick => _timer.tick;

  @override
  void cancel() {
    _onCancel(_timer);
    _timer.cancel();
  }
}
