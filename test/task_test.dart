import 'dart:async';

import 'package:multitasking/misc/progress.dart';
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
  _testSleep();
  _testStart();
  _testStatus();
  _testWaitAll();
  _testWhenAll();
  _testWhenAny();
  _testWhenEach();
  _testWithCancellation();
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

  test('Task token: outer token', () async {
    Future<void> f() async {
      return Task.run(() async {
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
  test('Task.delay(): Task.delay(100)', () async {
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

  test('Task.delay(): Task.delay(0, token)', () async {
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

  test('Task.delay(): Task.delay(100 ms, token(200 ms))', () async {
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

  test('Task.delay(): Task.delay(200 ms, token(100 ms))', () async {
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

  test('Task.delay(): Task.delay(-1 ms)', () async {
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

  test('Task.exception: access to force _finalizer.detach(task);', () async {
    final task = Task.run(() {
      throw Exception();
    });

    await _delay(0);

    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception?.error, isA<Exception>(), reason: 'exception.error');
    expect(task.exception?.stackTrace, isA<StackTrace>(),
        reason: 'exception.stackTrace');
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

  test('Task as Future: access _future after completed', () async {
    final task = Task.run(() async {
      return 42;
    });

    await _delay(100);
    final result = await task;

    expect(result, equals(42), reason: 'count');
  });
}

void _testOnExit() {
  test('Task.onExit(): when has error', () async {
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

  test('Task.onExit(): when has no error', () async {
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

  test('Task.onExit(): when current task == _main()', () async {
    expect(
      () => Zone.root.run(() => Task.onExit((task) {})),
      throwsA(isA<TaskStateError>()),
      reason: 'error',
    );
  });

  test('Task.onExit(): when task terminated', () async {
    var count = 0;
    final task = Task.run(() {
      Timer(Duration(milliseconds: 50), () {
        count++;
        expect(
          Task.current.isTerminated,
          isTrue,
          reason: 'Task.current.isTerminated',
        );
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

  test('Task.onExit(): calling more than once', () async {
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

  test('Task.result: access to force _finalizer.detach(task);', () async {
    final task = Task.run<int>(() {
      throw Exception();
    });

    await _delay(0);

    expect(() => task.result, throwsA(isA<Exception>()), reason: 'result');
  });
}

void _testSleep() {
  test('Task.sleep(): Task.sleep(100)', () async {
    var count = 0;
    Timer(Duration(milliseconds: 50), () {
      count++;
    });

    Timer(Duration(milliseconds: 150), () {
      count++;
    });

    await Task.sleep(100);

    expect(count, equals(1), reason: 'count');
  });

  test('Task.sleep(): Task.sleep(0, token)', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    cts.cancel();

    Object? error;
    try {
      await Task.sleep(0, token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task.sleep(): Task.sleep(100 ms, token(200 ms))', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    Timer(Duration(milliseconds: 200), cts.cancel);

    Object? error;
    try {
      await Task.sleep(100, token);
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
  });

  test('Task.sleep(): Task.sleep(200 ms, token(100 ms))', () async {
    final cts = CancellationTokenSource();
    final token = cts.token;
    Timer(Duration(milliseconds: 100), cts.cancel);

    Object? error;
    try {
      await Task.sleep(200, token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task.sleep(): Task.sleep(-1 ms)', () async {
    Object? error;
    try {
      await Task.sleep(-1);
    } catch (e) {
      error = e;
    }

    expect(error, isA<ArgumentError>(), reason: 'error');
  });
}

void _testStart() {
  test('Task.start(): status != TaskStatus.created)', () async {
    final task = Task.run(() {
      return 42;
    });

    await task;

    expect(task.start, throwsA(isA<TaskStateError>()), reason: 'start');
  });

  test('Task.start(): zone == null', () async {
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

void _testWhenAll() {
  test('Task.whenAll(): empty task list', () async {
    var count = 0;
    var total = 0;
    final progress = Progress((({int count, int total}) value) {
      count = value.count;
      total = value.total;
    });
    final result = await Task.whenAll([], progress: progress);

    expect(result, equals(<AnyTask>[]), reason: 'result');
    expect(count, equals(0), reason: 'count');
    expect(total, equals(0), reason: 'total');
  });

  test('Task.whenAll(): without errors', () async {
    var count = 0;
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        count++;
        return i;
      });

      tasks.add(t);
    }

    final results = await Task.whenAll(tasks);
    expect(results, equals([0, 1]), reason: 'result');
    expect(count, equals(2), reason: 'count');
  });

  test('Task.whenAll(): with errors', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        throw Exception();
      });

      tasks.add(t);
    }

    Object? error;
    try {
      await Task.whenAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isA<AggregateError>(), reason: 'error');
    expect((error! as AggregateError).exceptions.length, equals(2),
        reason: 'error.exceptions.length');
  });

  test('Task.whenAll(): errors [failed, canceled]', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        if (i == 0) {
          throw Exception();
        } else {
          throw CancellationException();
        }
      });

      tasks.add(t);
    }

    Object? error;
    try {
      await Task.whenAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isA<AggregateError>(), reason: 'error');
    final exceptions = (error! as AggregateError).exceptions;
    expect(exceptions.length, equals(2), reason: 'exceptions.length');
    final exception1 = exceptions[0];
    final exception2 = exceptions[1];
    expect(exception1.error, isA<Exception>(), reason: 'exception1.error');
    expect(exception2.error, isA<CancellationException>(),
        reason: 'exception2.error');
  });

  test('Task.whenAll(): errors [canceled, canceled]', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        throw CancellationException();
      });

      tasks.add(t);
    }

    Object? error;
    try {
      await Task.whenAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('Task.whenAll(): progress', () async {
    var count = 0;
    var total = 0;
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        return i;
      });

      tasks.add(t);
    }

    final progress = Progress((({int count, int total}) value) {
      count = value.count;
      total = value.total;
    });
    unawaited(Task.whenAll(tasks, progress: progress));
    await _delay(75);
    expect(count, equals(1), reason: 'count');
    expect(total, equals(2), reason: 'total');
    await _delay(200);
    expect(count, equals(2), reason: 'count');
  });
}

void _testWhenAny() {
  test('Task.whenAny(): empty task list', () async {
    expect(
      () => Task.whenAny([]),
      throwsA(isA<ArgumentError>()),
      reason: 'error',
    );
  });

  test('Task.whenAny(): without errors', () async {
    var count = 0;
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        count++;
        return i;
      });

      tasks.add(t);
    }

    final task = await Task.whenAny(tasks);
    expect(task.result, equals(0), reason: 'result');
    expect(count, equals(1), reason: 'count');
  });

  test('Task.whenAny(): with errors', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        if (i == 0) {
          throw Exception();
        }

        return i;
      });

      tasks.add(t);
    }

    final task = await Task.whenAny(tasks);
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception?.error, isA<Exception>(), reason: 'exception');
  });

  test('Task.whenAny(): progress', () async {
    var count = 0;
    var total = 0;
    final tasks = <Task<int>>[];
    for (var i = 0; i < 2; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.delay(50 + 50 * i);
        return i;
      });

      tasks.add(t);
    }

    final progress = Progress((({int count, int total}) value) {
      count = value.count;
      total = value.total;
    });
    final task = await Task.whenAny(tasks, progress: progress);
    expect(task.result, equals(0), reason: 'result');
    expect(count, equals(1), reason: 'count');
    expect(total, equals(2), reason: 'total');
    await _delay(200);
    expect(count, equals(2), reason: 'count');
  });
}

void _testWhenEach() {
  test('Task.whenEach(): empty', () async {
    int? count;
    int? total;
    final progress = Progress((({int count, int total}) value) {
      count = value.count;
      total = value.total;
    });
    final stream = Task.whenEach(<Task<int>>[], progress: progress);
    final taskList = await stream.toList();
    final values = taskList.map((e) => e.result).toList();
    expect(values, equals(<int>[]), reason: 'results');
    expect(count, equals(0), reason: 'count');
    expect(total, equals(0), reason: 'total');
  });

  test('Task.whenEach(): has no error', () async {
    final tasks = <Task<int>>[];
    final delays = [200, 150, 100];
    for (var i = 0; i < 3; i++) {
      final index = i;
      final task = Task.run(() async {
        await _delay(delays[i]);
        return index;
      });

      tasks.add(task);
    }

    final stream = Task.whenEach(tasks);
    final taskList = await stream.toList();
    final values = taskList.map((e) => e.result).toList();
    expect(values, equals([2, 1, 0]), reason: 'results');
  });

  test('Task.whenEach(): has error', () async {
    final tasks = <Task<int>>[];
    final delays = [200, 150, 100];
    for (var i = 0; i < 3; i++) {
      final index = i;
      final task = Task.run(() async {
        await _delay(delays[i]);
        if (index == 1) {
          throw Exception();
        }

        return index;
      });

      tasks.add(task);
    }

    final values = <int>[];
    final stream = Task.whenEach(tasks);
    Object? error;
    try {
      final taskList = await stream.toList();
      final results = taskList.map((e) => e.result).toList();
      values.addAll(results);
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
  });

  test('Task.whenEach(): progress', () async {
    final tasks = <Task<int>>[];
    final delays = [200, 150, 100];
    for (var i = 0; i < 3; i++) {
      final index = i;
      final task = Task.run(() async {
        await _delay(delays[i]);
        return index;
      });

      tasks.add(task);
    }

    final report = <({int count, int total})>[];
    final progress = Progress(report.add);
    final stream = Task.whenEach(tasks, progress: progress);
    final taskList = await stream.toList();
    final values = taskList.map((e) => e.result).toList();
    expect(values, equals([2, 1, 0]), reason: 'results');
    expect(
        report,
        equals([
          (count: 1, total: 3),
          (count: 2, total: 3),
          (count: 3, total: 3),
        ]),
        reason: 'results');
  });
}

void _testWithCancellation() {
  test('Task.withCancellation(): cancel before', () async {
    final task = Task.run(() async {
      await _delay(100);
      return 42;
    });

    final cts = CancellationTokenSource(Duration(milliseconds: 50));
    final token = cts.token;
    Object? error;
    try {
      await task.withCancellation(token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    await _delay(100);
    expect(task.result, equals(42), reason: 'result');
  });

  test('Task.withCancellation(): cancel after', () async {
    final task = Task.run(() async {
      await _delay(50);
      return 42;
    });

    final cts = CancellationTokenSource(Duration(milliseconds: 100));
    final token = cts.token;
    Object? error;
    try {
      await task.withCancellation(token);
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(task.result, equals(42), reason: 'result');
  });

  test('Task.withCancellation(): task throws CancellationException', () async {
    final task = Task.run<int>(() async {
      throw CancellationException();
    });

    final cts = CancellationTokenSource(Duration(milliseconds: 100));
    final token = cts.token;
    Object? error;
    try {
      await task.withCancellation(token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
  });

  test('Task.withCancellation(): task throws Exception', () async {
    final task = Task.run<int>(() async {
      throw Exception();
    });

    final cts = CancellationTokenSource(Duration(milliseconds: 100));
    final token = cts.token;
    Object? error;
    try {
      await task.withCancellation(token);
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
  });
}
