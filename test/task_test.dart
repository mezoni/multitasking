import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
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
  test('Task.wait.All(): success', () async {
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
        List.filled(tasks.length, TaskStatus.successful),
        reason: 'Not all task state succeeded');
    expect(results, [0, 1, 2, 3], reason: 'Not all results valid');
  });

  test('Task.wait.All(): success and failure', () async {
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
