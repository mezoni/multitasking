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
/// - `task.result` (only after the task is terminated)
/// - `task.exception` (only after the task is terminated)
/// - `task.asStream()` (inherited from [Future])
/// - `task.catchError()` (inherited from [Future])
/// - `task.then()` (inherited from [Future])
/// - `task.timeout()` (inherited from [Future])
/// - `task.whenComplete()` (inherited from [Future])
///
/// It all comes down to the fact that when accessing the [_future] field of a
/// task, an instance of the [Future] object is created and at that moment its
/// life cycle begins.
final class Task<T> implements Future<T> {
  static final Object _taskKey = Object();

  static final Expando<AnyTask> _tempTasks = Expando();

  static final Finalizer<ErrorResult> _finalizer = Finalizer((result) {
    Zone.root.scheduleMicrotask(() {
      Error.throwWithStackTrace(result.error, result.stackTrace);
    });
  });

  static final AnyTask _main = Task._raw(TaskState.running, name: 'main()')
    .._id = 0;

  static int _taskId = 1;

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
  int _id = _taskId++;

  /// Returns the task name.
  final String? name;

  FutureOr<T> Function()? _action;

  ErrorResult? _exception;

  FutureOr<void> Function(AnyTask)? _onExit;

  T? _result;

  Completer<T>? _resultCompleter;

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
  }

  Task._raw(this._state, {this.name});

  /// Returns the task exception or `null`.
  ///
  /// If the exception is not yet available or no exception occurred, `null` is
  /// returned.\
  /// If an exception is available, it is returned and the exception is
  /// considered to have been observed.
  ErrorResult? get exception {
    switch (_state) {
      case TaskState.canceled:
      case TaskState.failed:
        if (_resultCompleter == null) {
          _finalizer.detach(this);
        }

        return _exception;
      default:
        return null;
    }
  }

  /// Returns a unique integer identifier for the task.
  int get id => _id;

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

  /// Returns the task result.
  ///
  /// If the task result is not yet available, a [TaskStateError] exception will be
  /// thrown.\
  /// If the task was canceled, a [TaskCanceledException] exception will be
  /// thrown.\
  /// If the task was failed, a task [exception] will be thrown.
  ///
  /// If rhe task [exception] is available, it is considered to have been
  /// observed.
  T get result {
    switch (_state) {
      case TaskState.completed:
        return _result as T;
      case TaskState.canceled:
      case TaskState.failed:
        final exception = _exception!;
        final error = exception.error;
        final stackTrace = exception.stackTrace;
        if (_resultCompleter == null) {
          _finalizer.detach(this);
        }

        Error.throwWithStackTrace(error, stackTrace);
      default:
        throw TaskStateError(
            "Result is not available for the task with the state '${_state.name}'");
    }
  }

  /// Returns task state ([TaskState]).
  TaskState get state => _state;

  ZoneStats? get zoneStats => _zoneStats;

  Future<T> get _future {
    var completer = _resultCompleter;
    if (completer != null) {
      return completer.future;
    }

    completer = Completer();
    switch (_state) {
      case TaskState.completed:
        completer.complete(_result);
        break;
      case TaskState.canceled:
      case TaskState.failed:
        final exception = _exception!;
        final error = exception.error;
        final stackTrace = exception.stackTrace;
        completer.completeError(error, stackTrace);
        _finalizer.detach(this);
        break;
      default:
    }

    _resultCompleter = completer;
    return completer.future;
  }

  @override
  Stream<T> asStream() {
    return _future.asStream();
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _future.catchError(onError, test: test);
  }

  /// Starts execution of the task.
  Future<void> start() async {
    if (_state != TaskState.created) {
      throw TaskStateError('Task has already been started: ${toString()}');
    }

    final action = _action;
    if (action == null) {
      throw TaskStateError(
          'Failed to start task without action: ${toString()}');
    }

    final zone = _zone;
    if (zone == null) {
      throw TaskStateError('Failed to start task without zone: ${toString()}');
    }

    _state = TaskState.running;
    unawaited(zone.run(() async {
      try {
        final value = await action();
        _result = value;
        _state = TaskState.completed;
        _resultCompleter?.complete(value);
      } catch (error, stackTrace) {
        final exception = ErrorResult(error, stackTrace);
        _exception = exception;
        if (error is TaskCanceledException) {
          _state = TaskState.canceled;
        } else {
          _state = TaskState.failed;
        }

        final completer = _resultCompleter;
        if (completer == null) {
          _finalizer.attach(this, exception, detach: this);
        } else {
          completer.completeError(error, stackTrace);
        }
      } finally {
        final handler = _onExit;
        if (handler != null) {
          _onExit = null;
          unawaited(zone.run(() async {
            await handler(this);
          }));
        }
      }
    }));
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  String toString() {
    if (name == null) {
      return 'Task($id)';
    }

    return "Task('$name', $id)";
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _future.whenComplete(action);
  }

  /// Waits for the task to complete and returns the result (or throws an
  /// exception) if the task completes before cancellation; otherwise, throws
  /// a [TaskCanceledException] exception.
  ///
  /// Parameters:
  ///
  /// - [token]: A token indicating that a cancellation has occurred.
  Task<T> withCancellation(CancellationToken token) {
    final tcs = TaskCompletionSource<T>();
    unawaited(() async {
      final handler = token.addHandler(tcs.trySetCanceled);
      try {
        final task = await whenAny([this, tcs.task]);
        if (task == this) {
          tcs.trySetResult(task.result);
        } else {
          tcs.trySetCanceled();
        }
      } on TaskCanceledException {
        tcs.trySetCanceled();
      } catch (e, s) {
        tcs.trySetError(e, s);
      } finally {
        token.removerHandler(handler);
      }
    }());

    return tcs.task;
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

  /// Assigns a `handler` for the [current] task that will be executed after the
  /// task is terminated
  ///
  /// The handler cannot be added to synthetic tasks.
  static void onExit(FutureOr<void> Function(AnyTask task) handler) {
    final current = Task.current;
    var isSynthetic = false;
    if (identical(current, _main)) {
      isSynthetic = true;
    } else {
      isSynthetic = Zone.current[_taskKey] == null;
    }

    if (isSynthetic) {
      throw TaskStateError(
          "Failed to add 'onExit()' handler to synthetic task: ${current.toString()}");
    }

    if (current.isTerminated) {
      throw TaskStateError(
          "'Task.onExit()' can only be called on an unterminated task: ${current.toString()}");
    }

    if (current._onExit != null) {
      throw TaskStateError(
          "'Task.onExit()' can only be called once: ${current.toString()}");
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
    if (token == null) {
      Timer(duration, completer.complete);
    } else {
      void Function()? handler;
      final timer = Timer(duration, () {
        if (!completer.isCompleted) {
          token.removerHandler(handler);
          completer.complete();
        }
      });

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
  @Deprecated(
      "Will be removed in the next version. It is recommended to use 'whenAll()' instead")
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
  final Completer<T> _completer = Completer();

  final Task<T> task = Task._raw(TaskState.running);

  TaskCompletionSource() {
    task._resultCompleter = _completer;
  }

  void setCanceled() {
    if (!_completer.isCompleted) {
      task._state = TaskState.canceled;
      _completer.completeError(TaskCanceledException(), StackTrace.current);
      return;
    }

    _errorSetTaskState();
  }

  void setError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      task._state = TaskState.failed;
      _completer.completeError(error, stackTrace);
      return;
    }

    _errorSetTaskState();
  }

  void setResult(T result) {
    if (!_completer.isCompleted) {
      task._state = TaskState.completed;
      _completer.complete(result);
      return;
    }
  }

  void trySetCanceled() {
    if (!_completer.isCompleted) {
      task._state = TaskState.canceled;
      _completer.completeError(TaskCanceledException(), StackTrace.current);
      return;
    }
  }

  void trySetError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      task._state = TaskState.failed;
      _completer.completeError(error, stackTrace);
      return;
    }
  }

  void trySetResult(T value) {
    if (!_completer.isCompleted) {
      task._state = TaskState.completed;
      _completer.complete(value);
      return;
    }
  }

  Never _errorSetTaskState() {
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
