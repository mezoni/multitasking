import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

import 'cancellation.dart';
import 'errors.dart';

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
/// It all comes down to the fact that when accessing the [_future] field of a task, an instance of the [Future] object is created and at that moment its life cycle begins.
final class Task<T> with _FutureMixin<T> {
  static const Duration _zeroDuration = Duration();

  static final Zone _onExitZone = _createOnExitZone();

  static final Object _taskKey = Object();

  static final Expando<AnyTask> _tempTasks = Expando();

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
  /// returned.
  @awaitNotRequired
  static AnyTask get current {
    final zone = Zone.current;
    if (identical(zone, Zone.root)) {
      return _main;
    }

    AnyTask? task = zone[_taskKey] as AnyTask?;
    if (task != null) {
      return task;
    }

    task = _tempTasks[zone];
    if (task != null) {
      return task;
    }

    task = Task<void>._raw(TaskState.running);
    _tempTasks[zone] = task;
    return task;
  }

  /// Returns a unique integer identifier for the task.
  final int id = _taskId++;

  ErrorResult? _exception;

  /// Returns the task name.
  final String? name;

  FutureOr<T> Function()? _action;

  bool _isCompleted = false;

  FutureOr<void> Function(AnyTask task)? _onExit;

  TaskState _state = TaskState.created;

  Result<T>? _result;

  Completer<T>? _resultCompleter;

  Zone? _zone;

  /// Creates a task with the specified [action] callback and [name].
  Task(FutureOr<T> Function() action, {this.name}) : _action = action {
    _zone = Zone.root.fork(
        specification: ZoneSpecification(
            handleUncaughtError: (self, parent, zone, error, stackTrace) {
          if (error is TaskCanceledError) {
            _complete(TaskState.cancelled, ErrorResult(error, stackTrace));
          } else {
            _complete(TaskState.failed, ErrorResult(error, stackTrace));
          }
        }),
        zoneValues: {_taskKey: this});
  }

  Task._raw(this._state, {this.name});

  ErrorResult? get exception {
    return _exception;
  }

  /// Returns `true` if the task is in the [TaskState.cancelled] state. ; otherwise, returns
  /// `false`.
  bool get isCanceled {
    return _state == TaskState.cancelled;
  }

  /// Returns `true` if the task is in the [TaskState.completed] state. ; otherwise, returns
  /// `false`.
  bool get isCompleted {
    return _state == TaskState.completed;
  }

  /// Returns `true` if the task is in the [TaskState.failed] state. ; otherwise, returns
  /// `false`.
  bool get isFailed {
    return _state == TaskState.failed;
  }

  /// Returns `true` if the task was started and it is not completed; otherwise,
  /// returns `false`.
  bool get isRunning {
    return _state == TaskState.running;
  }

  /// Returns `true` if the task was started for execution; otherwise, returns
  /// `false`.
  bool get isStarted {
    return _state != TaskState.created;
  }

  /// Returns `true` if the task was terminated; otherwise, returns `false`.
  bool get isTerminated {
    return _state != TaskState.running && _state != TaskState.created;
  }

  /// Returns task state ([TaskState]).
  TaskState get state => _state;

  /// Starts execution of the task.
  void start() async {
    if (_state != TaskState.created) {
      throw StateError('Task has already been started: ${toString()}');
    }

    final zone = _zone;
    if (zone == null) {
      throw StateError('Failed to start task: ${toString()}');
    }

    final action = _action;
    if (action == null) {
      throw StateError('Failed to start task: ${toString()}');
    }

    _state = TaskState.running;
    unawaited(zone.run(() async {
      try {
        final value = await action();
        _complete(TaskState.completed, ValueResult(value));
      } on TaskCanceledError catch (e, s) {
        _complete(TaskState.cancelled, ErrorResult(e, s));
      } catch (e, s) {
        _complete(TaskState.failed, ErrorResult(e, s));
      }
    }));
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

    _isCompleted = true;
    _state = state;
    if (result is ErrorResult) {
      _exception = result;
    }

    _onExitZone.runGuarded(() async {
      try {
        final onExit = _onExit;
        if (onExit != null) {
          await onExit(this);
        }
      } finally {
        _result = result;
        if (_resultCompleter != null) {
          _completeResult(_resultCompleter!, result);
        } else {
          if (_exception != null) {
            _finalizer.attach(this, _exception!, detach: this);
          }
        }
      }
    });
  }

  void _completeResult(Completer<T> completer, Result<T> result) {
    if (result.isValue) {
      final valueResult = result.asValue!;
      completer.complete(valueResult.value);
    } else {
      final errorResult = result.asError!;
      final error = errorResult.error;
      final stackTrace = errorResult.stackTrace;
      completer.completeError(error, stackTrace);
    }
  }

  @override
  Future<T> _getFuture() {
    if (_resultCompleter == null) {
      if (_state == TaskState.created) {
        throw StateError('Task has not started yet: ${toString()}');
      }

      _resultCompleter = Completer();
      if (_result != null) {
        _completeResult(_resultCompleter!, _result!);
        if (_result is ErrorResult) {
          _finalizer.detach(this);
        }
      }
    }

    return _resultCompleter!.future;
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
    final current = Task.current;
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
  static Future<void> sleep([int milliseconds = 0, CancellationToken? token]) {
    if (milliseconds < 0) {
      throw ArgumentError.value(
          milliseconds, 'milliseconds', 'Milliseconds must not be negative');
    }

    final duration = milliseconds == 0
        ? _zeroDuration
        : Duration(milliseconds: milliseconds);
    final completer = Completer<void>();
    void Function()? handler;
    final timer = Timer(duration, () {
      if (!completer.isCompleted) {
        token?.removerHandler(handler);
        completer.complete();
      }
    });

    if (token != null) {
      handler = token.addHandler(() {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TaskCanceledError(), StackTrace.current);
        }
      });
    }

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
  /// The task was cancelled (by throwing an exception [TaskCanceledError]).
  cancelled,

  /// The task was completed successfully.
  completed,

  /// The task has not yet started.
  created,

  /// The task was completed with an error.
  failed,

  /// The task is running.
  running,
}

mixin _FutureMixin<T> implements Future<T> {
  @override
  Stream<T> asStream() {
    return _getFuture().asStream();
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _getFuture().catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return _getFuture().then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _getFuture().timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _getFuture().whenComplete(action);
  }

  Future<T> _getFuture();
}
