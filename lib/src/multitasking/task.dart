import 'dart:async';
import 'dart:core';

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
  static AnyTask _current = _main;

  static final Finalizer<AsyncError> _finalizer = Finalizer((result) {
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
    return _current;
  }

  /// Returns the cancellation token for the current task.
  ///
  /// If a token was not specified when creating a task, an unmanaged
  /// [CancellationTokenSource] is created and its token is returned.\
  /// By convention, each task has a token, but not all tokens are manageable.
  static CancellationToken get token {
    final task = _current;
    task._token ??= CancellationTokenSource().token;
    return task._token!;
  }

  /// Returns a unique integer identifier for the task.
  int _id = _taskId++;

  /// Returns the task name.
  final String? name;

  FutureOr<T> Function()? _action;

  AsyncError? _exception;

  FutureOr<void> Function(AnyTask)? _onExit;

  T? _result;

  Completer<T>? _resultCompleter;

  TaskStatus _status;

  CancellationToken? _token;

  Zone? _zone;

  /// Creates a task with the specified callback function and [name].
  ///
  /// Parameters:
  ///
  /// - [action]: Callback function that will be executed.
  /// - [combineTokens]: Determines if the cancellation token of the current
  /// task ([Task.current]) should also trigger cancellation of the task being
  /// created (this task). If another cancellation [token] is provided, it is
  /// combined with token of the current task; otherwise, only the provided
  /// [token] is used. If this parameter is `false` and no [token] is provided,
  /// this task will not be linked to any external cancellation source.
  /// - [name]: The name that will be assigned to the task.
  /// - [token]: A cancellation token specifically created for this task.
  ///
  /// To run the created task, the [start] method must be used.
  ///
  /// Attaching a task to the current (outer) task does not imply that the outer
  /// task will wait for the inner tasks to complete.\
  /// Attaching tasks means that cancellation requests from outer tasks will
  /// propagate to the inner tasks.\
  /// A task can always be detached by calling the [Task.detach] method.
  Task(
    FutureOr<T> Function() action, {
    bool combineTokens = true,
    this.name,
    CancellationToken? token,
  })  : _action = action,
        _status = TaskStatus.created {
    final current = _current;
    if (combineTokens) {
      final currentToken = current._token;
      if (token != null && currentToken != null) {
        _token = CancellationTokenSource.createLinkedTokenSource(
          [token, currentToken],
        ).token;
      } else if (token != null) {
        _token = token;
      } else if (currentToken != null) {
        _token = currentToken;
      }
    } else {
      _token = token;
    }

    _zone = Zone.current.fork(
      specification: ZoneSpecification(
        run: _handleRun,
        runBinary: _handleRunBinary,
        runUnary: _handleRunUnary,
      ),
    );
  }

  Task._raw(this._status, {this.name});

  /// Returns the task exception or `null`.
  ///
  /// If the exception is not yet available or no exception occurred, `null` is
  /// returned.\
  /// If an exception is available, it is returned and the exception is
  /// considered to have been observed.
  AsyncError? get exception {
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

  /// Returns `true` if the task status is [TaskStatus.pending]; otherwise,
  /// returns `false`.
  bool get isPending {
    return _status == TaskStatus.pending;
  }

  /// Returns `true` if the task status is [TaskStatus.running]; otherwise,
  /// returns `false`.
  bool get isRunning {
    return _status == TaskStatus.running;
  }

  /// Returns `true` if the task status is [TaskStatus.succeeded]; otherwise,
  /// returns `false`.
  bool get isSucceeded {
    return _status == TaskStatus.succeeded;
  }

  /// Returns `true` if the task was terminated; otherwise, returns `false`.
  bool get isTerminated {
    switch (_status) {
      case TaskStatus.canceled:
      case TaskStatus.failed:
      case TaskStatus.succeeded:
        return true;
      default:
        return false;
    }
  }

  /// Returns the task result.
  ///
  /// If the task result is not yet available, a [TaskStateError] exception will
  /// be thrown.\
  /// If the task was canceled, a [CancellationException] exception will be
  /// thrown.\
  /// If the task was failed, a task [exception] will be thrown.
  ///
  /// If rhe task [exception] is available, it is considered to have been
  /// observed.
  T get result {
    switch (_status) {
      case TaskStatus.succeeded:
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
      case TaskStatus.succeeded:
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
        _status = TaskStatus.succeeded;
        _resultCompleter?.complete(value);
      } catch (error, stackTrace) {
        final exception = AsyncError(error, stackTrace);
        _exception = exception;
        if (error is CancellationException) {
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
  /// otherwise, throws a [CancellationException] exception.
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
      } on CancellationException {
        tcs.trySetCanceled();
      } catch (e, s) {
        tcs.trySetError(e, s);
      } finally {
        token.removerHandler(handler);
      }
    }());

    return tcs.task;
  }

  R _handleRun<R>(Zone self, ZoneDelegate parent, Zone zone, R Function() f) {
    final current = _current;
    if (identical(_zone, zone)) {
      _current = this;
    }

    try {
      return parent.run(zone, f);
    } finally {
      _current = current;
    }
  }

  R _handleRunBinary<R, T1, T2>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg1, T2 arg2) f,
    T1 arg1,
    T2 arg2,
  ) {
    final current = _current;
    if (identical(_zone, zone)) {
      _current = this;
    }

    try {
      return parent.runBinary(zone, f, arg1, arg2);
    } finally {
      _current = current;
    }
  }

  R _handleRunUnary<R, T1>(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    R Function(T1 arg) f,
    T1 arg,
  ) {
    final current = _current;
    if (identical(_zone, zone)) {
      _current = this;
    }

    try {
      return parent.runUnary(zone, f, arg);
    } finally {
      _current = current;
    }
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
  /// The handler cannot be added to `main()` tasks.
  static void onExit(FutureOr<void> Function(AnyTask task) handler) {
    final current = _current;
    if (identical(current, _main)) {
      throw TaskStateError(
          "Failed to add 'onExit()' handler to (${current.toString()}) task");
    }

    if (current.isTerminated) {
      throw TaskStateError(
          "Failed to add 'onExit()' handler to terminated task (${current.toString()})");
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
  /// - [combineTokens]: Determines if the cancellation token of the [current]
  /// task should also trigger cancellation of the task being created (this
  /// task). If another cancellation [token] is provided, it is combined with
  /// token of the [current] task; otherwise, only the provided [token] is used.
  /// If this parameter is `false` and no [token] is provided, this task will
  /// not be linked to any external cancellation source.
  /// - [name]: The name that will be assigned to the task.
  /// - [token]: A cancellation token specifically created for this task.
  ///
  /// Attaching a task to the current (outer) task does not imply that the outer
  /// task will wait for the inner tasks to complete.\
  /// Attaching tasks means that cancellation requests from outer tasks will
  /// propagate to the inner tasks.\
  /// A task can always be detached by calling the [Task.detach] method.
  static Task<T> run<T>(
    FutureOr<T> Function() action, {
    bool combineTokens = true,
    String? name,
    CancellationToken? token,
  }) {
    final task = Task<T>(
      action,
      combineTokens: combineTokens,
      name: name,
      token: token,
    );
    unawaited(task.start());
    return task;
  }

  /// Sleeps at specified time in milliseconds, thereby giving up control to
  /// the event loop. A [CancellationException] exception may be thrown if a
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
          completer.completeError(CancellationException(), StackTrace.current);
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

    final exceptions = <AsyncError>[];
    var hasFailed = true;
    var count = 0;
    tasks = tasks.toList();
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      unawaited(() async {
        try {
          await task;
        } catch (e, s) {
          exceptions.add(AsyncError(e, s));
          if (e is! CancellationException) {
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
  final Task<T> task = Task._raw(TaskStatus.pending);

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
      _completer.completeError(CancellationException(), StackTrace.current);
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

  /// Completes the [task] with the status [TaskStatus.succeeded].
  ///
  /// Parameters:
  ///
  /// - [result]: A value that represents a result.
  ///
  /// If the task has already been completed, this method throws a
  /// [TaskStateError] exception.
  void setResult(T result) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.succeeded;
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
      _completer.completeError(CancellationException(), StackTrace.current);
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

  /// Tries to complete the [task] with the status [TaskStatus.succeeded].
  ///
  /// - [result]: A value that represents a result.
  ///
  /// If the task has already been completed, this method does nothing.
  void trySetResult(T result) {
    if (!_completer.isCompleted) {
      task._status = TaskStatus.succeeded;
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
  /// The task was canceled.
  canceled,

  /// The task was created but is not running.
  created,

  /// The task was completed with an error.
  failed,

  /// The promised task awaits completion.
  pending,

  /// The task is running.
  running,

  /// The task was completed successfully.
  succeeded,
}
