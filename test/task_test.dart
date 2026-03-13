import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testFailed();
  _testWaitAll();
  _testZoneActivity();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testFailed() {
  const error10 = 'Error10';
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
      await Task.waitAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'has errors');
    final results = <int>[];
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      results.add(await task);
    }

    expect(tasks.map((e) => e.state),
        List.filled(tasks.length, TaskState.completed),
        reason: 'Not all task state succeeded');
    expect(results, [0, 1, 2, 3], reason: 'Not all results valid');
  });

  test('Task.wait.All(): success and failure', () async {
    const err = 'Error';

    final tasks = <Task<int>>[];
    for (var i = 0; i < 4; i++) {
      final t = Task.run<int>(name: 'task $i', () async {
        await Task.sleep(100);
        if (i % 2 == 0) {
          return i;
        }

        throw err;
      });

      tasks.add(t);
    }

    Object? error;
    try {
      await Task.waitAll(tasks);
    } catch (e) {
      error = e;
    }

    expect(error, isA<AggregateError>(), reason: 'has no errors');
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (i % 2 == 0) {
        expect(await task, i, reason: 'task $i result not valid');
      } else {
        try {
          await task;
        } catch (e) {
          expect(e, err, reason: 'task $i error not valid');
        }
      }
    }
  });
}

void _testZoneActivity() {
  test('Task zone activity: timer', () async {
    final t1 = Task.run(() {
      Timer(Duration(seconds: 1), () {
        //
      });
    });

    await t1;
    final tracker = t1.zoneStats!;
    expect(tracker.isZoneActive, true, reason: 'isZoneActive != true');
    await _delay(1300);
    expect(tracker.isZoneActive, false, reason: 'isZoneActive != false');
  });

  test('Task zone activity: timer.cancel()', () async {
    Timer? timer;
    final t1 = Task.run(() {
      timer = Timer(Duration(seconds: 1), () {
        //
      });
    });

    await t1;
    final tracker = t1.zoneStats!;
    timer?.cancel();
    expect(tracker.isZoneActive, false, reason: 'isZoneActive != false');
  });

  test('Task zone activity: timer long running)', () async {
    final t1 = Task.run(() {
      Timer(Duration(seconds: 1), () async {
        await _delay(1000);
      });
    });

    final tracker = t1.zoneStats!;
    Timer(Duration(milliseconds: 1200), () {
      expect(tracker.isZoneActive, true, reason: 'isZoneActive != true');
    });

    Timer(Duration(milliseconds: 2200), () {
      expect(tracker.isZoneActive, false, reason: 'isZoneActive != false');
    });

    await t1;
  });

  test('Task zone activity: microtask long running)', () async {
    final t1 = Task.run(() {
      scheduleMicrotask(() async {
        await _delay(2000);
      });
    });

    await t1;
    final zoneStats = t1.zoneStats!;
    Timer(Duration(milliseconds: 1200), () {
      expect(zoneStats.isZoneActive, true, reason: 'isZoneActive != true');
    });

    Timer(Duration(milliseconds: 2200), () {
      expect(zoneStats.isZoneActive, false, reason: 'isZoneActive != false');
    });
  });
}
