import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testCancellationToken();
  _testCurrent();
  _testDelay();
  _testException();
  _testFailed();
  _testFutureMembers();
  _testOnExit();
  _testResult();
  _testStart();
  _testStatus();
  _testWaitAll();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testCancellationToken() {
  test('Task.token: token.throwIfCanceled()', () async {
    Future<void> f() async {
      final token = Task.token;
      for (var i = 0; i < 10; i++) {
        await _delay(50);
        token.throwIfCanceled();
      }
    }

    final cts = CancellationTokenSource();
    final task = Task.run(token: cts.token, () async {
      await f();
    });

    Timer(Duration(milliseconds: 100), cts.cancel);

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task token: cts1.cancel()', () async {
    final cts1 = CancellationTokenSource();
    Future<void> f() async {
      return Task.run(token: cts1.token, () async {
        final token = Task.token;
        for (var i = 0; i < 10; i++) {
          await _delay(50);
          token.throwIfCanceled();
        }
      });
    }

    final cts2 = CancellationTokenSource();
    final task = Task.run(token: cts2.token, () async {
      await f();
    });

    Timer(Duration(milliseconds: 100), cts1.cancel);

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task token: cts2.cancel()', () async {
    final cts1 = CancellationTokenSource();
    Future<void> f() async {
      return Task.run(token: cts1.token, () async {
        final token = Task.token;
        for (var i = 0; i < 10; i++) {
          await _delay(50);
          token.throwIfCanceled();
        }
      });
    }

    final cts2 = CancellationTokenSource();
    final task = Task.run(token: cts2.token, () async {
      await f();
    });

    Timer(Duration(milliseconds: 100), cts2.cancel);

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task token: combineTokens: false', () async {
    Future<void> f() async {
      return Task.run(combineTokens: false, () async {
        final token = Task.token;
        for (var i = 0; i < 10; i++) {
          await _delay(50);
          token.throwIfCanceled();
        }
      });
    }

    final cts = CancellationTokenSource();
    final task = Task.run(token: cts.token, () async {
      await f();
    });

    Timer(Duration(milliseconds: 100), cts.cancel);

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
  });

  test('Task.token: token = null', () async {
    Future<void> f() async {
      return Task.run(() async {
        final token = Task.token;
        for (var i = 0; i < 10; i++) {
          await _delay(50);
          token.throwIfCanceled();
        }
      });
    }

    final task = Task.run(() async {
      await f();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
  });
}

void _testCurrent() {
  test('Task.current: this task', () async {
    AnyTask? root1;
    AnyTask? root2;
    AnyTask? root3;
    late AnyTask task1;
    late AnyTask task2;

    Zone.root.run(() {
      root1 = Task.current;
      root2 = Task.current;
      root3 = Task.current;
    });

    expect(root2, equals(root1), reason: 'root2');
    expect(root3, equals(root1), reason: 'root3');

    final current = Task.current;
    expect(current, equals(Task.current), reason: 'current');
    expect(current, equals(Task.current), reason: 'current');
    expect(current, equals(Task.current), reason: 'current');

    task1 = Task<void>(() async {
      await _delay(10);
      expect(Task.current, equals(task1), reason: 'current1');
      await _delay(10);
      expect(Task.current, equals(task1), reason: 'current1');
      await _delay(10);
      expect(Task.current, equals(task1), reason: 'current1');
      await _delay(10);
    });

    task2 = Task<void>(() async {
      expect(Task.current, equals(task2), reason: 'current2');
      await _delay(10);
      expect(Task.current, equals(task2), reason: 'current2');
      expect(Task.current, equals(task2), reason: 'current2');
    });

    unawaited(task1.start());
    unawaited(task2.start());
    await Task.whenAll([task1, task2]);

    expect(current, equals(Task.current), reason: 'current');
    expect(current, equals(Task.current), reason: 'current');
    expect(current, equals(Task.current), reason: 'current');

    Zone.root.run(() {
      root1 = Task.current;
      root2 = Task.current;
      root3 = Task.current;
    });

    expect(root2, equals(root1), reason: 'root2');
    expect(root3, equals(root1), reason: 'root3');
  });

  test('Task.current: runZoned(scheduleMicrotask())', () async {
    final task = Task.run(() async {
      final current = Task.current;
      runZoned(() {
        expect(Task.current, equals(current), reason: 'Task.current');
        scheduleMicrotask(() {
          expect(Task.current, equals(current), reason: 'Task.current');
        });
      });
    });

    await task;
  });
}

void _testDelay() {
  test('Task.delay: Task.delay(100)', () async {
    var count = 0;
    Timer(Duration(milliseconds: 50), () {
      count++;
    });

    Timer(Duration(milliseconds: 150), () {
      count++;
    });

    await Task.delay(100);

    expect(count, equals(1), reason: 'count');
  });

  test('Task.delay: Task.delay(0, token)', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    cts.cancel();

    Object? error;
    try {
      await Task.delay(0, token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task.delay: Task.delay(100 ms, token(200 ms))', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    Timer(Duration(milliseconds: 200), cts.cancel);

    Object? error;
    try {
      await Task.delay(100, token);
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
  });

  test('Task.delay: Task.delay(200 ms, token(100 ms))', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    Timer(Duration(milliseconds: 100), cts.cancel);

    Object? error;
    try {
      await Task.delay(200, token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task.delay: Task.delay(-1 ms)', () async {
    Object? error;
    try {
      await Task.delay(-1);
    } catch (e) {
      error = e;
    }

    expect(error, isA<ArgumentError>(), reason: 'error');
  });
}

void _testException() {
  test('Task.exception: when has error', () async {
    final task = Task.run(() {
      throw Exception();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception?.error, isA<Exception>(), reason: 'exception.error');
    expect(task.exception?.stackTrace, isA<StackTrace>(),
        reason: 'exception.stackTrace');
  });

  test('Task.exception: when has no error', () async {
    final task = Task.run(() {
      return 42;
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(task.exception, isNull, reason: 'exception');
  });
}

void _testFailed() {
  final error10 = Exception('Error10');
  test('Task failure: Exception in body', () async {
    var exit10 = false;
    final t1 = Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      await _delay(100);
      throw error10;
    });

    Object? error;
    try {
      await t1;
    } catch (e) {
      error = e;
    }

    expect(exit10, true, reason: 'exit10 != true');
    expect(error, error10, reason: 'error != $error10');
  });

  test('Task failure: Exception in timer', () async {
    var exit10 = false;
    Object? error;
    var t1 = runZonedGuarded(() {
      return Task.run<int>(() async {
        Task.onExit((task) {
          exit10 = true;
        });

        Timer(Duration(milliseconds: 100), () {
          throw error10;
        });

        await _delay(100);
        return 1;
      });
    }, (e, s) {
      error = e;
    });

    t1 = t1!;
    await t1;
    expect(exit10, true, reason: 'exit10 != true');
    expect(error, error10, reason: 'error != $error10');
  });
}

void _testFutureMembers() {
  test('Task as Future: asStream()', () async {
    final task = Task.run(() {
      return 42;
    });

    final events = <Object?>[];
    final stream = task.asStream();
    await stream.listen(events.add).asFuture<void>();
    expect(events, equals([42]), reason: 'result');
  });

  test('Task as Future: catchError()', () async {
    final task = Task.run(() {
      throw Exception();
    });

    Object? error;
    Object? stackTrace;
    try {
      await task.catchError((Object e, Object? s) {
        error = e;
        stackTrace = s;
        return 42;
      });
    } catch (e) {
      //
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(stackTrace, isA<StackTrace>(), reason: 'stackTrace');
  });

  test('Task as Future: catchError(test)', () async {
    final task = Task.run(() {
      throw Exception();
    });

    Object? error;
    Object? stackTrace;
    try {
      await task.catchError((Object e, Object? s) {
        error = e;
        stackTrace = s;
        return 42;
      }, test: (error) {
        return error is! Exception;
      });
    } catch (e) {
      //
    }

    expect(error, isNull, reason: 'error');
    expect(stackTrace, isNull, reason: 'stackTrace');
  });

  test('Task as Future: then()', () async {
    final task = Task.run(() {
      return 42;
    });

    final result = await task.then((value) => value * 2);
    expect(result, equals(42 * 2), reason: 'result');
  });

  test('Task as Future: timeout()', () async {
    final task = Task.run(() async {
      await _delay(50);
      return 42;
    });

    final result = await task.timeout(Duration.zero, onTimeout: () {
      return 0;
    });
    await _delay(100);

    expect(result, equals(0), reason: 'result');
  });

  test('Task as Future: whenComplete()', () async {
    var count = 0;
    final task = Task.run(() async {
      await _delay(50);
      return 42;
    });

    await task.whenComplete(() {
      count++;
    });

    expect(count, equals(1), reason: 'count');
  });
}

void _testOnExit() {
  test('Task onExit(): when has error', () async {
    var count = 0;
    final task = Task.run<int>(() async {
      Task.onExit((task) {
        count++;
      });

      await _delay(0);
      throw Exception();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count, equals(1), reason: 'count');
  });

  test('Task onExit(): when has no error', () async {
    var count = 0;
    final task = Task.run<int>(() async {
      Task.onExit((task) {
        count++;
      });

      await _delay(0);
      count++;
      return 42;
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(count, equals(2), reason: 'count');
  });

  test('Task onExit(): when current task == _main()', () async {
    expect(
      () => Zone.root.run(() => Task.onExit((task) {})),
      throwsA(isA<TaskStateError>()),
      reason: 'error',
    );
  });

  test('Task onExit(): when current task == _main()', () async {
    var count = 0;
    final task = Task.run(() {
      Timer(Duration(milliseconds: 50), () {
        count++;
        expect(
          () => Task.onExit((task) {}),
          throwsA(isA<TaskStateError>()),
          reason: 'error',
        );
      });
    });

    await task;
    await _delay(100);
    expect(count, equals(1), reason: 'count');
  });

  test('Task onExit(): calling more than once', () async {
    final task = Task.run(() {
      Task.onExit((task) {});

      expect(
        () => Task.onExit((task) {}),
        throwsA(isA<TaskStateError>()),
        reason: 'error',
      );
    });

    await task;
  });
}

void _testResult() {
  test('Task.result: TaskStatus.canceled', () async {
    final task = Task.run<int>(() {
      throw CancellationException();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
    expect(() => task.result, throwsA(isA<CancellationException>()),
        reason: 'result');
  });

  test('Task.result: TaskStatus.created', () async {
    final task = Task(() {
      return 42;
    });

    expect(task.status, equals(TaskStatus.created), reason: 'status');
    expect(() => task.result, throwsA(isA<TaskStateError>()), reason: 'result');
  });

  test('Task.result: TaskStatus.failed', () async {
    final task = Task.run<int>(() {
      throw Exception();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
    expect(() => task.result, throwsA(isA<Exception>()), reason: 'result');
  });

  test('Task.result: TaskStatus.pending', () async {
    final completer = TaskCompletionSource<int>();
    final task = completer.task;
    expect(task.status, equals(TaskStatus.pending), reason: 'status');
    expect(() => task.result, throwsA(isA<TaskStateError>()), reason: 'result');
  });

  test('Task.result: TaskStatus.running', () async {
    final completer = Completer<int>();
    final task = Task.run(() async {
      await completer.future;
    });

    expect(task.status, equals(TaskStatus.running), reason: 'status');
    expect(() => task.result, throwsA(isA<TaskStateError>()), reason: 'result');
    completer.complete(42);
  });

  test('Task.result: TaskStatus.succeeded', () async {
    final task = Task.run(() {
      return 42;
    });

    await task;

    expect(task.status, equals(TaskStatus.succeeded), reason: 'status');
    expect(task.result, equals(42), reason: 'result');
  });
}

void _testStart() {
  test('Task.start: status != TaskStatus.created)', () async {
    final task = Task.run(() {
      return 42;
    });

    await task;

    expect(task.start, throwsA(isA<TaskStateError>()), reason: 'start');
  });

  test('Task.start: zone == null', () async {
    final completer = TaskCompletionSource<int>();
    final task = completer.task;
    expect(task.start, throwsA(isA<TaskStateError>()), reason: 'start');
  });
}

void _testStatus() {
  test('Task.status: TaskStatus.canceled', () async {
    final task = Task.run(() {
      throw CancellationException();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
    expect(task.isCanceled, isTrue, reason: 'isCanceled');
    expect(task.isTerminated, isTrue, reason: 'isTerminated');
  });

  test('Task.status: TaskStatus.created', () async {
    final task = Task(() {});
    expect(task.status, equals(TaskStatus.created), reason: 'status');
    expect(task.isCreated, isTrue, reason: 'isCreated');
    expect(task.isTerminated, isFalse, reason: 'isTerminated');
  });

  test('Task.status: TaskStatus.failed', () async {
    final task = Task.run(() {
      throw Exception();
    });

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
    expect(task.isFailed, isTrue, reason: 'isFailed');
    expect(task.isTerminated, isTrue, reason: 'isTerminated');
  });

  test('Task.status: TaskStatus.pending', () async {
    final completer = TaskCompletionSource<void>();
    final task = completer.task;
    expect(task.status, equals(TaskStatus.pending), reason: 'status');
    expect(task.isPending, isTrue, reason: 'isPending');
    expect(task.isTerminated, isFalse, reason: 'isTerminated');
  });

  test('Task.status: TaskStatus.running', () async {
    final completer = Completer<void>();
    final task = Task(() async {
      await completer.future;
    });

    unawaited(task.start());
    expect(task.status, equals(TaskStatus.running), reason: 'status');
    expect(task.isRunning, isTrue, reason: 'isRunning');
    completer.complete();
  });

  test('Task.status: TaskStatus.succeeded', () async {
    final task = Task.run(() {});

    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(task.status, equals(TaskStatus.succeeded), reason: 'status');
    expect(task.isSucceeded, isTrue, reason: 'isSucceeded');
    expect(task.isTerminated, isTrue, reason: 'isTerminated');
  });
}

void _testWaitAll() {
  test('Task.waitAll(): success', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 4; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.sleep(100);
        return i;
      });

      tasks.add(t);
    }

    Object? error;
    try {
      await Task.whenAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'has errors');
    final results = <int>[];
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      results.add(await task);
    }

    expect(tasks.map((e) => e.status),
        List.filled(tasks.length, TaskStatus.succeeded),
        reason: 'Not all task state succeeded');
    expect(results, [0, 1, 2, 3], reason: 'Not all results valid');
  });

  test('Task.waitAll(): success and failure', () async {
    final error = Exception('Error');
    final tasks = <Task<int>>[];
    for (var i = 0; i < 4; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.sleep(100);
        if (i % 2 == 0) {
          return i;
        }

        throw error;
      });

      tasks.add(t);
    }

    Object? err;
    try {
      await Task.whenAll(tasks);
    } catch (e) {
      err = e;
    }

    expect(err, isA<AggregateError>(), reason: 'has no errors');
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (i % 2 == 0) {
        expect(await task, i, reason: 'task $i result not valid');
      } else {
        try {
          await task;
        } catch (e) {
          expect(e, error, reason: 'task $i error not valid');
        }
      }
    }
  });
}
