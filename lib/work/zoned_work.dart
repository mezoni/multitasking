import 'dart:async';

import '../multitasking.dart';
import 'work.dart';

typedef _AnyZonedWork = ZonedWork<Object?>;

/// A [ZonedWork] is an operation for executing a computation inside the [Zone]
/// container with the possibility of externally controlled termination.
///
//// The recommended way to terminate a [ZonedWork] is to request a cancellation
///  using a cancellation token.
///
/// ⚠️ Warning:\
/// The following warnings concern the various consequences of terminating
/// [ZonedWork] using the [terminate] method.
///
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
///
/// Termination is implemented by attempting to stop code execution in various
/// ways (this does not apply to voluntary termination using a cancellation
/// token) and includes the following actions:
///
/// - Canceling timers
/// - Replacing timer handlers with empty callbacks
/// - Replacing microtasks with empty callbacks
/// - Replacing registered callbacks that allow `null` returns with empty
/// callbacks
///
/// When using objects created before [ZonedWork] was created, these objects may
/// cause memory leaks.\
/// Example: If (inside [ZonedWork]) subscribe to a broadcast stream created
/// before the creation of [ZonedWork], and then terminate [ZonedWork] by
/// calling the [terminate] method, the subscription will never be canceled.
class ZonedWork<T> implements Work<T> {
  static final Object _key = Object();

  static Zone? _lastZone;

  static _AnyZonedWork? _lastZonedWork;

  /// Returns an instance of the current [ZonedWork] or `null`.
  static ZonedWork<Object?>? get current {
    final zone = Zone.current;
    if (identical(zone, _lastZone)) {
      return _lastZonedWork;
    }

    _lastZone = zone;
    _lastZonedWork = null;
    if (identical(zone, Zone.root)) {
      return null;
    }

    // Look up the key in the zone and in the parent zone.
    if (zone[_key] case final ZonedWork<Object?> work) {
      _lastZonedWork = work;
      return work;
    }

    var parent = zone.parent?.parent;
    if (parent == null) {
      return null;
    }

    if (parent[_key] case final ZonedWork<Object?> work) {
      _lastZonedWork = work;
      return work;
    }

    parent = zone.parent?.parent;
    while (parent != null) {
      if (parent[_key] case final ZonedWork<Object?> work) {
        _lastZonedWork = work;
        return work;
      }

      parent = zone.parent?.parent;
    }

    return null;
  }

  final FutureOr<T> Function() _computation;

  final Completer<void> _completer = Zone.root.run(Completer<void>.new);

  bool _isStarted = false;

  bool _isTerminationRequested = false;

  Object? _error;

  FutureOr<void> Function(ZonedWork<Object?> work)? _onExit;

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
    _zone = Zone.root.fork(
        specification: ZoneSpecification(
          createPeriodicTimer: _createPeriodicTimer,
          createTimer: _createTimer,
          handleUncaughtError: _handleUncaughtError,
          registerBinaryCallback: _registerBinaryCallback,
          registerUnaryCallback: _registerUnaryCallback,
          registerCallback: _registerCallback,
          scheduleMicrotask: _scheduleMicrotask,
        ),
        zoneValues: {_key: this});
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
    final completer = Completer<T>();
    unawaited(Zone.root.run(() async {
      unawaited(() async {
        try {
          result = await _zone.run(() {
            return Task.run(token: _token, () async {
              await Future<void>.delayed(Duration.zero);
              return _computation();
            });
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
      try {
        if (_isTerminationRequested) {
          completer.completeError(CancellationException(), StackTrace.current);
        } else if (_error != null) {
          completer.completeError(_error!, _stackTrace ?? StackTrace.empty);
        } else if (hasResult) {
          completer.complete(result as T);
        } else {
          completer.completeError(
              StateError('Computation ended without result'),
              StackTrace.current);
        }
      } finally {
        final onExit = _onExit;
        if (onExit != null) {
          onExit(this);
        }
      }
    }));

    return completer.future;
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

  ZoneBinaryCallback<R, T1, T2> _registerBinaryCallback<R, T1, T2>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg1, T2 arg2) f,
  ) {
    R callback(T1 arg1, T2 arg2) {
      if (_isDeactivated) {
        if (null is R) {
          return null as R;
        }
      }

      return f(arg1, arg2);
    }

    return parent.registerBinaryCallback(zone, callback);
  }

  ZoneCallback<R> _registerCallback<R>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function() f,
  ) {
    R callback() {
      if (_isDeactivated) {
        if (null is R) {
          return null as R;
        }
      }

      return f();
    }

    return parent.registerCallback(zone, callback);
  }

  ZoneUnaryCallback<R, T1> _registerUnaryCallback<R, T1>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg) f,
  ) {
    R callback(T1 arg) {
      if (_isDeactivated) {
        if (null is R) {
          return null as R;
        }
      }

      return f(arg);
    }

    return parent.registerUnaryCallback(zone, callback);
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

  /// Adds an [onExit] handler to the current [ZonedWork] instance; if the
  /// handler has already been added previously or there is no current
  /// [ZonedWork] instance, then throws a [StateError] exception.
  ///
  /// Parameters:
  ///
  /// - [handler]: The handler that will be executed after termination.
  ///
  /// The handler will be executed once in one of the following cases (whichever
  /// comes first):
  ///
  /// - The computation will complete with a result or with an error
  /// - The computation will terminate due to the call to the [terminate] method
  /// - The computation will terminate in an unpredictable way
  ///
  /// The handler will be executed in the root zone and it should not throw
  /// exceptions.
  ///
  /// Example:
  ///
  /// ```dart
  /// if (ZonedWork.current != null) {
  ///   ZonedWork.onExit((work) {
  ///     // Free resources, close handles, cancel operations
  ///   });
  /// }
  /// ```
  static bool onExit(FutureOr<void> Function(ZonedWork<Object?> work) handler) {
    final current = ZonedWork.current;
    if (current == null) {
      throw StateError(
          "Failed to add `onExit()` handler, no current instance of 'ZonedWork'");
    }

    if (current._onExit != null) {
      throw StateError("'ZonedWork.onExit()' can only be called once");
    }

    current._onExit = handler;
    return true;
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
