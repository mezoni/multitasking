import 'dart:async';
import 'dart:core';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

import '../../misc/progress.dart';
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

  static final AnyTask _main = Task._raw(TaskStatus.running, name: 'main()')
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

    task = Task<void>._raw(TaskStatus.running);
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

  TaskStatus _status;

  Zone? _zone;

  /// Creates a task with the specified callback function and [name].
  ///
  /// Parameters:
  ///
  /// - [action]: Callback function that will be executed.
  /// - [name]: The name that will be assigned to the task.
  ///
  /// To run the created task, the [start] method must be used.
  Task(FutureOr<T> Function() action, {this.name})
      : _action = action,
        _status = TaskStatus.created {
    _zone = Zone.current.fork(
      zoneValues: {_taskKey: this},
    );
  }

  Task._raw(this._status, {this.name});

  /// Returns the task exception or `null`.
  ///
  /// If the exception is not yet available or no exception occurred, `null` is
  /// returned.\
  /// If an exception is available, it is returned and the exception is
  /// considered to have been observed.
  ErrorResult? get exception {
    switch (_status) {
      case TaskStatus.canceled:
      case TaskStatus.failed:
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

  /// Returns `true` if the task status is [TaskStatus.canceled]; otherwise,
  /// returns `false`.
  bool get isCanceled {
    return _status == TaskStatus.canceled;
  }

  /// Returns `true` if the task status is [TaskStatus.created]; otherwise,
  /// returns `false`.
  bool get isCreated {
    return _status == TaskStatus.created;
  }

  /// Returns `true` if the task status is [TaskStatus.failed]; otherwise,
  /// returns `false`.
  bool get isFailed {
    return _status == TaskStatus.failed;
  }

  /// Returns `true` if the task status is [TaskStatus.incomplete]; otherwise,
  /// returns `false`.
  bool get isIncomplete {
    return _status == TaskStatus.incomplete;
  }

  /// Returns `true` if the task status is [TaskStatus.running]; otherwise,
  /// returns `false`.
  bool get isRunning {
    return _status == TaskStatus.running;
  }

  /// Returns `true` if the task status is [TaskStatus.successful]; otherwise,
  /// returns `false`.
  bool get isSuccessful {
    return _status == TaskStatus.successful;
  }

  /// Returns `true` if the task was terminated; otherwise, returns `false`.
  bool get isTerminated {
    switch (_status) {
      case TaskStatus.canceled:
      case TaskStatus.failed:
      case TaskStatus.successful:
        return true;
      default:
        return false;
    }
  }

  /// Returns the task result.
  ///
  /// If the task result is not yet available, a [TaskStateError] exception will
  /// be thrown.\
  /// If the task was canceled, a [TaskCanceledException] exception will be
  /// thrown.\
  /// If the task was failed, a task [exception] will be thrown.
  ///
  /// If rhe task [exception] is available, it is considered to have been
  /// observed.
  T get result {
    switch (_status) {
      case TaskStatus.successful:
        return _result as T;
      case TaskStatus.canceled:
      case TaskStatus.failed:
        final exception = _exception!;
        final error = exception.error;
        final stackTrace = exception.stackTrace;
        if (_resultCompleter == null) {
          _finalizer.detach(this);
        }

        Error.throwWithStackTrace(error, stackTrace);
      default:
        throw TaskStateError(
            "Result is not available for the task with the status '${_status.name}'");
    }
  }

  /// Returns task status ([TaskStatus]).
  TaskStatus get status => _status;

  Future<T> get _future {
    var completer = _resultCompleter;
    if (completer != null) {
      return completer.future;
    }

    completer = Completer();
    switch (_status) {
      case TaskStatus.successful:
        completer.complete(_result);
        break;
      case TaskStatus.canceled:
      case TaskStatus.failed:
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
    if (_status != TaskStatus.created) {
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

    _status = TaskStatus.running;
    unawaited(zone.run(() async {
      try {
        final value = await action();
        _result = value;
        _status = TaskStatus.successful;
        _resultCompleter?.complete(value);
      } catch (error, stackTrace) {
        final exception = ErrorResult(error, stackTrace);
        _exception = exception;
        if (error is TaskCanceledException) {
          _status = TaskStatus.canceled;
        } else {
          _status = TaskStatus.failed;
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

  /// Waits for the task to complete and returns the result (or error) if the
  /// task completes (successfully or with error) before cancellation request;
  /// otherwise, throws a [TaskCanceledException] exception.
  ///
  /// Parameters:
  ///
  /// - [token]: A token indicating that a cancellation request has occurred.
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

  /// Creates a task that will complete successfully after a time delay or will
  /// be completed with status [TaskStatus.canceled] if a cancellation request
  /// was initiated before or during the execution of this method.
  ///
  /// Parameters:
  ///
  /// - [milliseconds]:Delay time in milliseconds.
  /// - [token]: A token indicating that a cancellation request has occurred.
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
  /// task is terminated.
  ///
  /// Parameters:
  ///
  /// - [handler]: A callback function that will be executed immediately after
  /// the task terminates execution.
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

  /// Creates and starts a task with the specified callback and [name].
  ///
  /// Parameters:
  ///
  /// - [action]: Callback function that will be executed.
  /// - [name]: The name that will be assigned to the task.
  static Task<T> run<T>(FutureOr<T> Function() action, {String? name}) {
    final task = Task<T>(action, name: name);
    unawaited(task.start());
    return task;
  }

  /// Sleeps at specified time in milliseconds, thereby giving up control to
  /// the event loop. A [TaskCanceledException] exception may be thrown if a
  /// cancellation request was initiated before or after calling this method.
  ///
  /// Parameters:
  ///
  /// - [milliseconds]:Delay time in milliseconds.
  /// - [token]: A token indicating that a cancellation request has occurred.
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

  /// Performs a wait operation for tasks to complete.
  ///
  /// Parameters:
  ///
  /// -[tasks]: A list of tasks to wait for.
  /// -[progress]: A monitor that will be called when each task is completed.
  ///
  /// When all tasks have completed successfully, returns a new task with the
  /// results of the awaited tasks.
  ///
  /// If one of the tasks fails, the returned task will be completed with the
  /// status [TaskStatus.failed].
  ///
  /// If none of the tasks failed, but at least one of the tasks was canceled,
  /// then the returned task will be completed with the status
  /// [TaskStatus.canceled].
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

  /// Performs a wait operation for tasks to complete. As soon as one of the
  /// tasks is completed, it will be immediately returned as the result of this
  /// method.
  ///
  /// Parameters:
  ///
  /// -[tasks]: A list of tasks to wait for.
  /// -[progress]: A monitor that will be called when each task is completed.
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
  /// Parameters:
  ///
  /// -[tasks]: A list of tasks to wait for.
  /// -[progress]: A monitor that will be called when each task is completed.
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

/// A [TaskCompletionSource] is a  producer of the tasks that can complete with
/// a value, with an error, or in a canceled state.
class TaskCompletionSource<T> {
  final Completer<T> _completer = Completer();

  /// The task produced by this source.
  final Task<T> task = Task._raw(TaskStatus.incomplete);

  /// Creates an instance of [TaskCompletionSource].
  TaskCompletionSource() {
    task._resultCompleter = _completer;
  }

  /// Completes the [task] with the status [TaskStatus.canceled].
  ///
  /// If the task has already been completed, this method throws a
  /// [TaskStateError] exception.
  void setCanceled() {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.canceled;
      _completer.completeError(TaskCanceledException(), StackTrace.current);
      return;
    }

    _errorSetTaskStatus();
  }

  /// Completes the [task] with the status [TaskStatus.failed].
  ///
  /// Parameters:
  ///
  /// - [error]: A value that represents an exception.
  /// - [stackTrace]: A value that represents a stack trace.
  ///
  /// If the task has already been completed, this method throws a
  /// [TaskStateError] exception.
  void setError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.failed;
      _completer.completeError(error, stackTrace);
      return;
    }

    _errorSetTaskStatus();
  }

  /// Completes the [task] with the status [TaskStatus.successful].
  ///
  /// Parameters:
  ///
  /// - [result]: A value that represents a result.
  ///
  /// If the task has already been completed, this method throws a
  /// [TaskStateError] exception.
  void setResult(T result) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.successful;
      _completer.complete(result);
      return;
    }
  }

  /// Tries to complete the [task] with the status [TaskStatus.canceled].
  ///
  /// If the task has already been completed, this method does nothing.
  void trySetCanceled() {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.canceled;
      _completer.completeError(TaskCanceledException(), StackTrace.current);
      return;
    }
  }

  /// Tries to complete the [task] with the status [TaskStatus.failed].
  ///
  /// Parameters:
  ///
  /// - [error]: A value that represents an exception.
  /// - [stackTrace]: A value that represents a stack trace.
  ///
  /// If the task has already been completed, this method does nothing.
  void trySetError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.failed;
      _completer.completeError(error, stackTrace);
      return;
    }
  }

  /// Tries to complete the [task] with the status [TaskStatus.successful].
  ///
  /// - [result]: A value that represents a result.
  ///
  /// If the task has already been completed, this method does nothing.
  void trySetResult(T result) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.successful;
      _completer.complete(result);
      return;
    }
  }

  Never _errorSetTaskStatus() {
    throw TaskStateError('Failed to set final status of completed task');
  }
}

/// Represents the status of a task.
enum TaskStatus {
  /// The task was canceled (by throwing an exception [TaskCanceledException]).
  canceled,

  /// The task has not yet started.
  created,

  /// The task was completed with an error.
  failed,

  /// The task is waiting for completion from the task completion source.
  incomplete,

  /// The task is running.
  running,

  /// The task was completed successfully.
  successful,
}
