import 'dart:async';
import 'dart:core';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

import '../../misc/progress.dart';
import 'cancellation.dart';
import 'errors.dart';
import 'zone_stats.dart';

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
  static final Object _taskKey = Object();

  static final Expando<AnyTask> _tempTasks = Expando();

  static final Finalizer<ErrorResult> _finalizer = Finalizer((result) {
    Zone.root.scheduleMicrotask(() {
      Error.throwWithStackTrace(result.error, result.stackTrace);
    });
  });

  static final AnyTask _main = Task._raw(TaskState.running, name: 'main()');

  /// Global error handler for tasks `onExit` handlers.
  static void Function(Object error, StackTrace? stackTrace)? handleOnExitError;

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

  /// Returns the task name.
  final String? name;

  FutureOr<T> Function()? _action;

  final Completer<T> _completer = Completer();

  ErrorResult? _exception;

  bool _isAttachedToFinalizer = false;

  bool _isObserved = false;

  FutureOr<void> Function(AnyTask task)? _onExit;

  T? _result;

  TaskState _state = TaskState.created;

  Zone? _zone;

  ZoneStats? _zoneStats;

  /// Creates a task with the specified [action] callback and [name].
  Task(
    FutureOr<T> Function() action, {
    this.name,
  }) : _action = action {
    final zoneStats = ZoneStats();
    var specification = zoneStats.specification;
    specification = ZoneSpecification.from(specification);
    _zoneStats = zoneStats;
    _zone = Zone.current.fork(
      specification: specification,
      zoneValues: {_taskKey: this},
    );
    unawaited(_handleCompletion());
  }

  Task._raw(this._state, {this.name}) : _zoneStats = ZoneStats() {
    unawaited(_handleCompletion());
  }

  ErrorResult? get exception {
    return _exception;
  }

  /// Returns `true` if the task is in the [TaskState.canceled] state. ; otherwise, returns
  /// `false`.
  bool get isCanceled {
    return _state == TaskState.canceled;
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

  T get result {
    if (_state == TaskState.completed) {
      return _result as T;
    }

    throw TaskStateError(
        "Result is not available for the task with the state '${_state.name}'");
  }

  /// Returns task state ([TaskState]).
  TaskState get state => _state;

  ZoneStats? get zoneStats => _zoneStats;

  /// Starts execution of the task.
  Future<void> start() async {
    if (_state != TaskState.created) {
      throw TaskStateError('Task has already been started: ${toString()}');
    }

    final zone = _zone;
    if (zone == null) {
      throw TaskStateError('Failed to start task: ${toString()}');
    }

    final action = _action;
    if (action == null) {
      throw TaskStateError('Failed to start task: ${toString()}');
    }

    _state = TaskState.running;
    unawaited(zone.run(() async {
      try {
        final value = await action();
        _completer.complete(value);
      } catch (e, s) {
        _completer.completeError(e, s);
      }
    }));
  }

  @override
  String toString() {
    if (name == null) {
      return 'Task($id)';
    }

    return "Task('$name', $id)";
  }

  @override
  Future<T> _getFuture() {
    if (_isAttachedToFinalizer) {
      _isAttachedToFinalizer = false;
      _finalizer.detach(this);
    }

    _isObserved = true;
    return _completer.future;
  }

  Future<void> _handleCompletion() async {
    try {
      final value = await _completer.future;
      _result = value;
      _state = TaskState.completed;
    } catch (e, s) {
      final exception = ErrorResult(e, s);
      _exception = exception;
      if (e is TaskCanceledException) {
        _state = TaskState.canceled;
      } else {
        _state = TaskState.failed;
      }

      if (!_isObserved) {
        _isAttachedToFinalizer = true;
        _finalizer.attach(this, exception, detach: this);
      }
    } finally {
      final onExit = _onExit;
      if (onExit != null) {
        onExit(this);
      }
    }
  }

  /// Creates a task that will complete after a time delay.
  static Task<void> delay([int milliseconds = 0, CancellationToken? token]) {
    if (milliseconds < 0) {
      throw ArgumentError.value(
          milliseconds, 'milliseconds', 'Must not be negative');
    }

    final duration = milliseconds == 0
        ? const Duration()
        : Duration(milliseconds: milliseconds);
    final tcs = TaskCompletionSource<void>();
    final task = tcs.task;
    if (token == null) {
      Timer(duration, () {
        tcs.setResult(null);
      });
    } else {
      void Function()? handler;
      final timer = Timer(duration, () {
        if (!task.isTerminated) {
          token.removerHandler(handler);
          tcs.setResult(null);
        }
      });

      handler = token.addHandler(() {
        timer.cancel();
        if (!task.isTerminated) {
          tcs.setCanceled();
        }
      });
    }

    return task;
  }

  /// Assigns a `handler` for the [current] task that will be executed as the
  /// last thing before it terminates.
  ///
  /// Only one `handler` can be assigned to a task.
  ///
  /// If an exception is thrown in a `handler`, it will be considered an
  /// `unhandled` exception.\
  /// If an exception is also thrown during task execution, that exception will
  /// be considered an `unobserved` exception.\
  /// This will cause the exception thrown in that `handler` to be rethrown
  /// before the `unobserved` exception.\
  /// This is because the `unobserved` exception is in a state of `awaiting` for
  /// appropriate handling and it is not considered an `unhandled` exception at
  /// this stage.
  static void onExit(FutureOr<void> Function(AnyTask task) handler) {
    final current = Task.current;
    if (current._onExit != null) {
      throw TaskStateError("'Task.onExit()' can be called only once");
    }

    current._onExit = handler;
  }

  /// Creates and starts a task with the specified [action] callback and
  /// [name].
  static Task<T> run<T>(FutureOr<T> Function() action, {String? name}) {
    final task = Task<T>(action, name: name);
    unawaited(task.start());
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
          milliseconds, 'milliseconds', 'Must not be negative');
    }

    final duration = milliseconds == 0
        ? const Duration()
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
          completer.completeError(TaskCanceledException(), StackTrace.current);
        }
      });
    }

    return completer.future;
  }

  /// Performs a wait operation for tasks to complete.\
  /// If all tasks are completed successfully, then this method will also
  /// complete successfully.
  ///
  /// If one of the tasks fails or is canceled, then this method will complete
  /// with an [AggregateError] error that will contain all errors.
  ///
  /// If the [progress] parameter is specified, it will call the `report()`
  /// method whenever each task completes.
  static Future<void> waitAll<T>(
    List<Task<T>> tasks, {
    Progress<({int count, int total})>? progress,
  }) {
    final completer = Completer<void>();
    if (tasks.isEmpty) {
      progress?.report((count: 0, total: 0));
      completer.complete();
      return completer.future;
    }

    final exceptions = <ErrorResult>[];
    var count = 0;
    tasks = tasks.toList();
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(() async {
        try {
          await task;
        } catch (e, s) {
          exceptions.add(ErrorResult(e, s));
        } finally {
          count++;
          if (progress != null) {
            progress.report((count: count, total: tasks.length));
          }

          if (count == tasks.length) {
            if (exceptions.isEmpty) {
              completer.complete();
            } else {
              final error = AggregateError(exceptions);
              completer.completeError(error);
            }
          }
        }
      }());
    }

    return completer.future;
  }

  /// Performs a wait operation for tasks to complete.\
  /// When all tasks have completed successfully, returns a new task with the
  /// results of the awaited tasks.
  ///
  /// If one of the tasks fails, the returned task will be completed in the
  /// `failed` state.
  ///
  /// If none of the tasks failed, but at least one of the tasks was canceled,
  /// then the returned task will be completed in the `canceled` state.
  ///
  /// If the [progress] parameter is specified, it will call the `report()`
  /// method whenever each task completes.
  static Task<List<T>> whenAll<T>(
    List<Task<T>> tasks, {
    Progress<({int count, int total})>? progress,
  }) {
    final tcs = TaskCompletionSource<List<T>>();
    if (tasks.isEmpty) {
      progress?.report((count: 0, total: 0));
      tcs.setResult([]);
      return tcs.task;
    }

    final exceptions = <ErrorResult>[];
    var hasFailed = true;
    var count = 0;
    tasks = tasks.toList();
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(() async {
        try {
          await task;
        } catch (e, s) {
          exceptions.add(ErrorResult(e, s));
          if (e is! TaskCanceledException) {
            hasFailed = true;
          }
        } finally {
          count++;
          if (progress != null) {
            progress.report((count: count, total: tasks.length));
          }

          if (count == tasks.length) {
            if (exceptions.isEmpty) {
              final list = <T>[];
              for (var i = 0; i < tasks.length; i++) {
                final task = tasks[i];
                list.add(task.result);
              }

              tcs.setResult(list);
            } else {
              if (hasFailed) {
                final error = AggregateError(exceptions);
                tcs.setError(error, StackTrace.current);
              } else {
                tcs.setCanceled();
              }
            }
          }
        }
      }());
    }

    return tcs.task;
  }

  /// Performs a wait operation for tasks to complete.\
  /// As soon as one of the tasks is completed, it will be immediately returned
  /// as the result of this method.
  ///
  /// If the [progress] parameter is specified, it will call the `report()`
  /// method whenever each task completes.
  static Task<Task<T>> whenAny<T>(
    List<Task<T>> tasks, {
    Progress<({int count, int total})>? progress,
  }) {
    if (tasks.isEmpty) {
      throw ArgumentError('Must not be empty', 'tasks');
    }

    final tcs = TaskCompletionSource<Task<T>>();
    var count = 0;
    tasks = tasks.toList();
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(() async {
        try {
          await task;
        } catch (e) {
          // Ignore exception
        } finally {
          count++;
          progress?.report((count: count, total: tasks.length));
          if (count == 1) {
            tcs.setResult(task);
          }
        }
      }());
    }

    return tcs.task;
  }

  /// Returns a [Stream] to which each [Task] in the [tasks] list will be added,
  /// in the order in which they were completed.
  ///
  /// If the [progress] parameter is specified, it will call the `report()`
  /// method whenever each task completes.
  static Stream<Task<T>> whenEach<T>(
    List<Task<T>> tasks, {
    Progress<({int count, int total})>? progress,
  }) {
    if (tasks.isEmpty) {
      progress?.report((count: 0, total: 0));
      return Stream.empty();
    }

    final controller = StreamController<Task<T>>();
    var count = 0;
    tasks = tasks.toList();
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(() async {
        try {
          await task;
        } catch (e) {
          // Ignore exception
        } finally {
          count++;
          progress?.report((count: count, total: tasks.length));
          controller.add(task);
        }

        if (count == tasks.length) {
          await controller.close();
        }
      }());
    }

    return controller.stream;
  }
}

class TaskCompletionSource<T> {
  final Task<T> task = Task._raw(TaskState.running);

  void setCanceled() {
    final completer = task._completer;
    if (completer.isCompleted) {
      _errorSteTaskState();
    }

    trySetCanceled();
  }

  void setError(Object error, StackTrace stackTrace) {
    final completer = task._completer;
    if (completer.isCompleted) {
      _errorSteTaskState();
    }

    trySetError(error, stackTrace);
  }

  void setResult(T result) {
    final completer = task._completer;
    if (completer.isCompleted) {
      _errorSteTaskState();
    }

    trySetResult(result);
  }

  void trySetCanceled() {
    final completer = task._completer;
    if (completer.isCompleted) {
      return;
    }

    completer.completeError(TaskCanceledException(), StackTrace.current);
  }

  void trySetError(Object error, StackTrace stackTrace) {
    final completer = task._completer;
    if (completer.isCompleted) {
      return;
    }

    completer.completeError(error, stackTrace);
  }

  void trySetResult(T value) {
    final completer = task._completer;
    if (completer.isCompleted) {
      return;
    }

    completer.complete(value);
  }

  Never _errorSteTaskState() {
    throw TaskStateError('Failed to set final state of completed task');
  }
}

/// Represents the state of a task.
enum TaskState {
  /// The task was canceled (by throwing an exception [TaskCanceledError]).
  canceled,

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
