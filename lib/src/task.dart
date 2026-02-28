import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

import 'errors.dart';
import 'task_zone_interceptor.dart';

/// Type alias for a task of any type.
typedef AnyTask = Task<Object?>;

/// A [Task] is an object representing some operation that will complete in the future.\
/// Tasks are executed asynchronously and cooperatively.\
/// Cooperative multitasking is a concurrency model where tasks voluntarily yield control (using `await`).
///
/// The result of a task execution is the result of computing the value of the task action. It can be either a value or an exception.\
/// The task itself is an object of [Future] that wraps the result of the computation.\
/// The main difference between the task and the [Future] is as follows:
///
/// **The task does not begin executing the computation immediately after it is created**.\
/// The task supports delayed start. Or it may never even be started.\
/// After the computation is completed, the task captures the result of the computation.
///
/// **In case of completion with an exception, the task does not propagate this exception to the unhandled exception handler immediately.**\
/// This unobserved exception is stored in the relevant task object instance until it the task is aware that an exception has been observed.\
/// If the task isn not aware that an exception was observed, this exception will be propagated in the task finalizer ([Finalizer]).\
/// If the finalizer is not executed by runtime (due to Dart SDK limitations), the exception will remain unobserved.\
/// For this reason, due to the limited functionality of the finalizer, it is recommended to always observe task exceptions (detecting, catching, handling).
///
/// Exceptions in task can be observed in one of the following ways:
///
/// - `await task`
/// - `task.future`
/// - `Task.waitAll()`
/// - `task.asStream()` (inherited from [Future])
/// - `task.catchError()` (inherited from [Future])
/// - `task.then()` (inherited from [Future])
/// - `task.timeout()` (inherited from [Future])
/// - `task.whenComplete()` (inherited from [Future])
///
/// It all comes down to the fact that when accessing the [future] field of a task, an instance of the [Future] object is created and at that moment its life cycle begins.
///
/// **Each task runs in its own zone. When the computation action completes, the task zone deactivated**:
///
/// This includes the following:
///
/// - All active timers are deactivated
/// - All created timers are deactivated immediately after they are created
/// - Any pending callbacks will be executed as the empty action callbacks
/// - All micro tasks scheduling calls are replaced with empty action callbacks
/// - In all the `registerCallback` methods, the callback is replaced with a callback with the exception of [TaskStoppedError].
final class Task<T> with _FutureMixin<T> {
  static const Duration _zeroDuration = Duration(seconds: 0);

  static final Zone _onExitZone = _createOnExitZone();

  static AnyTask _current = _main;

  static final Finalizer<ErrorResult> _finalizer = Finalizer((result) {
    Zone.root.scheduleMicrotask(() {
      Error.throwWithStackTrace(result.error, result.stackTrace);
    });
  });

  static final AnyTask _main = Task._raw(TaskState.running, name: 'main()');

  /// Global error handler for tasks `onExit` handlers.
  static FutureOr<void> Function(Object error, StackTrace? stackTrace)?
      handleOnExitError;

  static int _taskId = 0;

  /// Returns the currently running task.
  ///
  /// If no explicit task is currently running, the synthetic task `main()` is
  /// returned. The `main()` task is an always `running` task (root task) that
  /// cannot be stopped.
  @awaitNotRequired
  static AnyTask get current => _current;

  /// Returns a unique integer identifier for the task.
  final int id = _taskId++;

  /// Returns the task name.
  final String? name;

  FutureOr<T> Function()? _action;

  FutureOr<void> Function(AnyTask task)? _onExit;

  Future<T>? _future;

  TaskZoneInterceptor<T>? _interceptor;

  bool _isCompleted = false;

  TaskState _state = TaskState.created;

  final Completer<Result<T>> _taskCompleter = Completer();

  /// Creates a task with the specified [action] callback and [name].
  Task(FutureOr<T> Function() action, {this.name}) : _action = action {
    _main;
    _interceptor = TaskZoneInterceptor(
        enter: _enter,
        leave: _leave,
        onError: (error, stackTrace) {
          _complete(TaskState.failed, ErrorResult(error, stackTrace));
        });
  }

  Task._raw(this._state, {this.name});

  /// Return the result of the task execution, wrapped in [Future].
  ///
  /// If the task execution resulted in an error, then [Future] will throw an
  /// exception. This is normal behavior because it is the only way to know how
  /// the task completed.
  ///
  /// The internal structure of the task and the mechanism of its operation
  /// imply that access to the task execution result (field [future]) must be
  /// necessarily performed. Even in that case, if there is no direct need to
  /// obtain the result.
  ///
  /// This rule is due to the fact that the Dart SDK does not guarantee that the
  /// finalizer will be called. Because the finalizer ([_finalizer]) is
  /// delegated the task of propagating unobserved exceptions.
  @override
  Future<T> get future async {
    if (_future != null) {
      return _future as Future<T>;
    }

    if (_state == TaskState.created) {
      throw StateError('Task has not yet been started: ${toString()}');
    }

    final result = await _taskCompleter.future;
    if (result.isValue) {
      final valueResult = result.asValue!;
      final value = valueResult.value;
      final future = Future.value(value);
      _future = future;
      return future;
    } else {
      final errorResult = result.asError!;
      _finalizer.detach(this);
      final error = errorResult.error;
      final stackTrace = errorResult.stackTrace;
      final future = Future<T>.error(error, stackTrace);
      _future = future;
      return future;
    }
  }

  /// Returns `true` if the task was started and it is not completed; otherwise,
  /// returns `false`.
  bool get isRunning {
    return _state == TaskState.running;
  }

  /// Returns `true` if the task was started for execution; otherwise, returns
  /// `false`.
  bool get isStarted => _state != TaskState.created;

  /// Returns `true` if the task was terminated; otherwise, returns `false`.
  bool get isTerminated =>
      !(_state == TaskState.created || _state == TaskState.running);

  /// Returns task state ([TaskState]).
  TaskState get state => _state;

  /// Starts execution of the task.
  void start() async {
    if (_state != TaskState.created) {
      throw StateError('Task has already been started: ${toString()}');
    }

    final interceptor = _interceptor;
    if (interceptor == null) {
      throw StateError('Failed to start task: ${toString()}');
    }

    final action = _action;
    if (action == null) {
      throw StateError('Failed to start task: ${toString()}');
    }

    _state = TaskState.running;
    final zone = interceptor.zone;
    unawaited(zone.run(() async {
      try {
        final value = await action();
        _complete(TaskState.completed, ValueResult(value));
      } catch (e, s) {
        _complete(TaskState.failed, ErrorResult(e, s));
      }
    }));
  }

  /// Initializes the actions necessary to stopping the task.
  ///
  /// Unlike terminating a task gracefully, stopping a task results in the loss
  /// of unsaved changes or data.
  void stop() {
    if (identical(this, _main)) {
      throw StateError('Task \'$this\' is the root task and cannot be stopped');
    }

    try {
      throw TaskStoppedError();
    } catch (error, stackTrace) {
      _complete(TaskState.stopped, ErrorResult(error, stackTrace));
    }
  }

  @override
  String toString() {
    if (name == null) {
      return 'Task($id)';
    }

    return 'Task(\'$name\', $id)';
  }

  void _complete(TaskState state, Result<T> result) {
    if (_isCompleted) {
      return;
    }

    final interceptor = _interceptor;
    if (interceptor != null) {
      interceptor.deactivate();
    }

    _isCompleted = true;
    _state = state;
    _onExitZone.runGuarded(() async {
      try {
        final onExit = _onExit;
        if (onExit != null) {
          await onExit(this);
        }
      } finally {
        _taskCompleter.complete(result);
        if (result.isError) {
          _finalizer.attach(this, result.asError!, detach: this);
        }
      }
    });
  }

  AnyTask _enter() {
    final current = _current;
    _current = this;
    return current;
  }

  void _leave(AnyTask task) {
    _current = task;
  }

  /// Assigns a handler for the current task ([Task.current]) that will be
  /// executed as the last thing before it terminates.
  ///
  /// Only one handler can be assigned to a task.
  ///
  /// It is important to understand that executing a handler in the context of a
  /// task is not possible, since the task execution context can be deactivated
  /// (execution of microtasks and timers is disabled).
  ///
  /// For this reason, the handler is executed in the fork of the root zone
  /// ([Zone.root]), that is, independently of the task execution context.
  ///
  /// All unhandled exceptions that may occur will be dispatched to the global
  /// `onExit` error handler [Task.handleOnExitError].
  ///
  /// If [Task.handleOnExitError] is not set, then all unhandled errors that
  /// occur in the `onExit` processing will be propagated to the root zone
  /// ([Zone.root]).
  static void onExit(FutureOr<void> Function(AnyTask task) handler) {
    final current = _current;
    if (current._onExit != null) {
      throw StateError('\'Task.onExit()\' can be called only once');
    }

    current._onExit = handler;
  }

  /// Creates and starts a task with the specified [action] callback and
  /// [name].
  static Task<T> run<T>(FutureOr<T> Function() action, {String? name}) {
    final task = Task<T>(action, name: name);
    task.start();
    return task;
  }

  /// Allows to switch the event loop context to execute other scheduled code
  /// in the microtask and timer queue.
  ///
  /// The continuation of execution will be scheduled (delayed in time) for a
  /// time interval not less than the specified duration.
  ///
  /// There is no guarantee that the time delay will match the specified one
  /// with high accuracy.
  static Future<void> sleep([int milliseconds = 0]) {
    if (milliseconds < 0) {
      throw ArgumentError.value(
          milliseconds, 'milliseconds', 'Milliseconds must not be negative');
    }

    final duration = milliseconds == 0
        ? _zeroDuration
        : Duration(milliseconds: milliseconds);
    final completer = Completer<void>();
    Timer(duration, completer.complete);
    return completer.future;
  }

  static Future<void> waitAll<T>(List<Task<T>> tasks) async {
    if (tasks.isEmpty) {
      return Future.delayed(_zeroDuration);
    }

    final completer = Completer<void>();
    final exceptions = <ErrorResult>[];
    void complete() {
      if (exceptions.isEmpty) {
        completer.complete();
      }

      final error = AggregateError(exceptions);
      completer.completeError(error);
    }

    final length = tasks.length;
    tasks = tasks.toList();
    var n = 0;
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(task.then((_) {
        if (++n == length) {
          complete();
        }
      }).onError((error, stackTrace) {
        error ??= '$error';
        exceptions.add(ErrorResult(error, stackTrace));
        if (++n == length) {
          complete();
        }
      }));
    }

    return completer.future;
  }

  static Zone _createOnExitZone() {
    return Zone.root.fork(specification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
      if (handleOnExitError != null) {
        handleOnExitError!(error, stackTrace);
      } else {
        parent.handleUncaughtError(zone, error, stackTrace);
      }
    }));
  }
}

/// Represents the state of a task.
enum TaskState {
  /// The task was completed successfully.
  completed,

  /// The task has not yet started.
  created,

  /// The task was completed with an error.
  failed,

  /// The task is running.
  running,

  /// The task was stopped (was not completed).
  stopped
}

mixin _FutureMixin<T> implements Future<T> {
  Future<T> get future;

  @override
  Stream<T> asStream() {
    return future.asStream();
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return future.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return future.then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit,
      {FutureOr<dynamic> Function()? onTimeout}) {
    return future.timeout(timeLimit);
  }

  @override
  Future<T> whenComplete(FutureOr<dynamic> Function() action) {
    return future.whenComplete(action);
  }
}
