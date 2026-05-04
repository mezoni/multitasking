import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _tesCancellationToken();
  _testFailed();
  _testWaitAll();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
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

void _tesCancellationToken() {
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
