import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/src/errors.dart';
import 'package:test/test.dart';

void main() {
  _testStop();
  _testCompletion();
  _testFailed();
  _testWaitAll();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testCompletion() {
  test('Task completion', () async {
    var exit10 = false;
    Timer? timer1;
    Timer? timer2;
    final t1 = await Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      timer1 = Timer.periodic(Duration(milliseconds: 200), (timer) {
        //
      });

      timer2 = Timer(Duration(milliseconds: 200), () {
        //
      });

      await _delay(100);
      return 1;
    });

    await t1;

    expect(exit10, true, reason: 'exit10 != true');
    expect(timer1 != null, true, reason: 'timer1 == null');
    expect(timer2 != null, true, reason: 'timer2 == null');
    expect(!timer1!.isActive, true, reason: 'timer1.isActive');
    expect(!timer2!.isActive, true, reason: 'timer2.isActive');
  });
}

void _testFailed() {
  const error10 = 'Error10';
  test('Task failure: Exception in body', () async {
    var exit10 = false;
    final t1 = await Task.run<int>(() async {
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
    final t1 = await Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      Timer(Duration(milliseconds: 100), () {
        throw error10;
      });

      await _delay(100);
      return 1;
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
}

void _testStop() {
  test('Task.stop()', () async {
    var count10 = 0;
    var count11 = 0;
    var exit10 = false;
    Timer? timer1;
    Timer? timer2;
    final t1 = await Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      timer1 = Timer.periodic(Duration(milliseconds: 100), (timer) {
        count10++;
      });

      timer2 = Timer(Duration(milliseconds: 200), () {
        count10++;
      });

      await _delay(200);
      return 1;
    });

    Timer(Duration(milliseconds: 150), () {
      count11 = count10;
      t1.stop();
    });

    Object? error;
    try {
      await t1;
    } catch (e) {
      error = e;
    }

    await _delay(200);

    expect(count10 > 0, true, reason: 'count10 = 0');
    expect(count10, count11, reason: 'count0 != count11');
    expect(exit10, true, reason: 'exit10 != true');
    expect(timer1 != null, true, reason: 'timer1 == null');
    expect(timer2 != null, true, reason: 'timer2 == null');
    expect(!timer1!.isActive, true, reason: 'timer1.isActive');
    expect(!timer2!.isActive, true, reason: 'timer2.isActive');
    expect(error, isA<TaskStoppedError>(), reason: 'exit10 != true');
  });

  test('Task.stop(): Deactivate timer callbacks', () async {
    var exit10 = false;
    var ticks1 = 0;
    var ticks2 = 0;
    Timer? timer1;
    Timer? timer2;
    final t1 = await Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      timer1 = Timer.periodic(Duration(milliseconds: 300), (timer) {
        ticks1++;
      });

      timer2 = Timer(Duration(milliseconds: 300), () {
        ticks2++;
      });

      await _delay(200);
      return 1;
    });

    Timer(Duration(milliseconds: 150), t1.stop);

    Object? error;
    try {
      await t1;
    } catch (e) {
      error = e;
    }

    await _delay(500);

    expect(exit10, true, reason: 'exit10 != true');
    expect(timer1 != null, true, reason: 'timer1 == null');
    expect(timer2 != null, true, reason: 'timer2 == null');
    expect(!timer1!.isActive, true, reason: 'timer1.isActive');
    expect(!timer2!.isActive, true, reason: 'timer2.isActive');
    expect(ticks1, 0, reason: 'ticks1, != 0');
    expect(ticks2, 0, reason: 'ticks2 != 0');
    expect(error, isA<TaskStoppedError>(), reason: 'exit10 != true');
  });

  test('Task.stop() await Future.delayed()', () async {
    var count10 = 0;
    var count11 = 0;
    var exit10 = false;
    final t1 = await Task.run<int>(() async {
      Task.onExit((task) {
        exit10 = true;
      });

      await _delay(100);
      count10++;
      await _delay(100);
      count10++;
      await _delay(100);
      count10++;
      return 1;
    });

    Timer(Duration(milliseconds: 150), () {
      count11 = count10;
      t1.stop();
    });

    Object? error;
    try {
      await t1;
    } catch (e) {
      error = e;
    }

    await _delay(300);

    expect(count10 > 0, true, reason: 'count10 == 0');
    expect(count10, count11, reason: 'count0 != count11');
    expect(exit10, true, reason: 'exit10 != true');
    expect(error, isA<TaskStoppedError>(), reason: 'exit10 != true');
  });
}

void _testWaitAll() {
  test('Task.wait.All(): success', () async {
    final tasks = <Task<int>>[];
    for (var i = 0; i < 4; i++) {
      final t = await Task.run<int>(name: 'task $i', () async {
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
      final t = await Task.run<int>(name: 'task $i', () async {
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
