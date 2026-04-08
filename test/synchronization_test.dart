import 'dart:async';
import 'dart:collection';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';
import 'package:multitasking/synchronization/condition_variable.dart';
import 'package:multitasking/synchronization/counting_semaphore.dart';
import 'package:multitasking/synchronization/multiple_write_single_read_object.dart';
import 'package:multitasking/synchronization/reentrant_lock.dart';
import 'package:multitasking/synchronization/reset_events.dart';
import 'package:test/test.dart';

void main() {
  _testBinarySemaphore();
  _testConditionVariable();
  _testCountingSemaphore();
  _testManualResetEvent();
  _testMultipleWriteSingleReadObject();
  _testReentrantLock();
}

Future<void> _delay(int ms) {
  return Future.delayed(Duration(milliseconds: ms));
}

void _testBinarySemaphore() {
  test('BinarySemaphore.acquire()', () async {
    final sem = BinarySemaphore();
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    for (var i = 0; i < 5; i++) {
      final future = Future(() async {
        await sem.acquire();
        try {
          total++;
          count++;
          await _delay(100);
          if (max < count) {
            max = count;
          }

          count--;
        } finally {
          await sem.release();
        }
      });

      futures.add(future);
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(1), reason: 'max');
    expect(total, equals(futures.length), reason: 'total');
  });

  test('BinarySemaphore.tryAcquire(): With duration', () async {
    final sem = BinarySemaphore();
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    final timeouts = <Duration?>[];
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 50));
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 50));
    for (final timeout in timeouts) {
      futures.add(Future(() async {
        if (timeout == null) {
          await sem.acquire();
          try {
            total++;
            count++;
            await _delay(100);
            if (max < count) {
              max = count;
            }

            count--;
          } finally {
            await sem.release();
          }
        } else {
          if (await sem.tryAcquire(timeout)) {
            try {
              total++;
              count++;
              await _delay(100);
              if (max < count) {
                max = count;
              }

              count--;
            } finally {
              await sem.release();
            }
          }
        }
      }));
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(1), reason: 'max');
    expect(total, equals(futures.length ~/ 2), reason: 'total');
  });

  test('BinarySemaphore.tryAcquire(): With zero duration', () async {
    final sem = BinarySemaphore();
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    final timeouts = <Duration>[];
    timeouts.add(Duration());
    timeouts.add(Duration(milliseconds: 50));
    timeouts.add(Duration());
    timeouts.add(Duration(milliseconds: 150));
    for (final timeout in timeouts) {
      futures.add(Future(() async {
        if (await sem.tryAcquire(timeout)) {
          try {
            total++;
            count++;
            await _delay(100);
            if (max < count) {
              max = count;
            }

            count--;
          } finally {
            await sem.release();
          }
        }
      }));
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(1), reason: 'max');
    expect(total, equals(futures.length ~/ 2), reason: 'total');
  });
}

void _testConditionVariable() {
  test('ConditionVariable', () async {
    final lock = BinarySemaphore();
    final notEmpty = ConditionVariable(lock);
    final notFull = ConditionVariable(lock);
    const capacity = 4;
    final products = Queue<int>();
    var productId = 0;
    var produced = 0;
    var consumed = 0;

    Future<void> produce() async {
      await Future<void>.delayed(Duration(milliseconds: 100));
      final product = productId++;
      produced++;

      await lock.acquire();
      try {
        while (products.length == capacity) {
          await notFull.wait();
        }

        products.add(product);
        await notEmpty.notifyAll();
      } finally {
        await lock.release();
      }
    }

    Future<void> consume() async {
      // Unused un test
      // ignore: unused_local_variable
      int? product;
      await lock.acquire();
      try {
        while (products.isEmpty) {
          await notEmpty.wait();
        }

        product = products.removeFirst();
        await notFull.notifyAll();
      } finally {
        await lock.release();
      }

      await Future<void>.delayed(Duration(milliseconds: 100));
      consumed++;
    }

    final futures = <Future<void>>[];

    for (var i = 0; i < 5; i++) {
      futures.add(consume());
      futures.add(produce());
    }

    await Future.wait(futures);
    expect(products.isEmpty, isTrue, reason: 'products.isNotEmpty');
    expect(produced, equals(5), reason: 'produced');
    expect(consumed, equals(5), reason: 'consumed');
  });
}

void _testCountingSemaphore() {
  test('CountingSemaphore.acquire()', () async {
    final sem = CountingSemaphore(0, 2);
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    for (var i = 0; i < 5; i++) {
      final future = Future(() async {
        await sem.acquire();
        try {
          total++;
          count++;
          await _delay(100);
          if (max < count) {
            max = count;
          }

          count--;
        } finally {
          await sem.release();
        }
      });

      futures.add(future);
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(2), reason: 'max');
    expect(total, equals(5), reason: 'total');
  });

  test('CountingSemaphore.tryAcquire(): With duration', () async {
    final sem = CountingSemaphore(0, 2);
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    final timeouts = <Duration?>[];
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 50));
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 50));
    for (final timeout in timeouts) {
      futures.add(Future(() async {
        if (timeout == null) {
          await sem.acquire();
          try {
            total++;
            count++;
            await _delay(100);
            if (max < count) {
              max = count;
            }

            count--;
          } finally {
            await sem.release();
          }
        } else {
          if (await sem.tryAcquire(timeout)) {
            try {
              total++;
              count++;
              await _delay(100);
              if (max < count) {
                max = count;
              }

              count--;
            } finally {
              await sem.release();
            }
          }
        }
      }));
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(2), reason: 'max');
    expect(total, equals(3), reason: 'total');
  });

  test('CountingSemaphore.tryAcquire(): With zero duration', () async {
    final sem = CountingSemaphore(0, 2);
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    final timeouts = <Duration>[];
    timeouts.add(Duration());
    timeouts.add(Duration(milliseconds: 50));
    timeouts.add(Duration());
    timeouts.add(Duration(milliseconds: 150));
    for (final timeout in timeouts) {
      futures.add(Future(() async {
        if (await sem.tryAcquire(timeout)) {
          try {
            total++;
            count++;
            await _delay(100);
            if (max < count) {
              max = count;
            }

            count--;
          } finally {
            await sem.release();
          }
        }
      }));
    }

    await Future.wait(futures);
    expect(count, equals(0), reason: 'count');
    expect(max, equals(2), reason: 'max');
    expect(total, equals(3), reason: 'total');
  });
}

void _testManualResetEvent() {
  test('ManualResetEvent', () async {
    final evt = ManualResetEvent(false);
    var result = 0;
    var isOpen = true;
    Future<void> f() async {
      await evt.wait();
      if (isOpen) {
        result++;
      }
    }

    Timer.run(() async {
      isOpen = false;
      await evt.set();
    });

    await f();
    expect(result, equals(0), reason: 'result');
    isOpen = true;
    await f();
    expect(result, equals(1), reason: 'result');
  });
}

void _testMultipleWriteSingleReadObject() {
  test('MultipleWriteSingleReadObject', () async {
    final object = MultipleWriteSingleReadObject(0);
    final values = <int>[];
    final modes = <String>[];
    final tasks = <AnyTask>[];

    void scheduleTask(int ms, Future<void> Function() action) {
      final t = Task.run<void>(() async {
        await Task.sleep(ms);
        await action();
      });
      tasks.add(t);
    }

    void scheduleRead(int ms) {
      scheduleTask(ms, () async {
        final int v;
        var isLocked = false;
        if (object.isLocked) {
          isLocked = true;
          await object.wait();
        }

        final mode = isLocked ? 'wait/read' : 'read';
        modes.add(mode);
        v = object.read();
        values.add(v);
      });
    }

    void scheduleWrite(int ms) {
      scheduleTask(ms, () {
        return object.write((value) async {
          await Future<void>.delayed(Duration(milliseconds: 100));
          return ++value;
        });
      });
    }

    scheduleRead(0);
    scheduleWrite(0);
    scheduleWrite(0);
    scheduleRead(0);
    scheduleRead(200);
    scheduleRead(400);

    await Task.whenAll(tasks);
    expect(modes, equals(['read', 'wait/read', 'wait/read', 'read']),
        reason: 'modes');
    expect(values, equals([0, 2, 2, 2]), reason: 'values');
  });
}

void _testReentrantLock() {
  test('ReentrantLock: acquire()', () async {
    final m = ReentrantLock();
    final list = <String>[];
    final tasks = <AnyTask>[];
    var counter = 0;

    Future<void> f(int i) async {
      await m.acquire();
      try {
        await Future<void>.delayed(Duration(milliseconds: 50));
        counter++;
        list.add('${Task.current.name}$counter');
        if (i + 1 < 3) {
          await f(i + 1);
        }
      } finally {
        await m.release();
      }
    }

    for (var i = 0; i < 3; i++) {
      final t = Task.run(name: '$i', () => f(0));
      tasks.add(t);
    }

    await Task.whenAll(tasks);

    expect(list, equals(['01', '02', '03', '14', '15', '16', '27', '28', '29']),
        reason: 'list');
  });

  test('ReentrantLock: tryAcquire()', () async {
    final m = ReentrantLock();
    final list = <String>[];
    final tasks = <AnyTask>[];
    var counter = 0;

    Future<void> f(int i, Duration? timeout) async {
      if (timeout == null) {
        await m.acquire();
        try {
          await Future<void>.delayed(Duration(milliseconds: 50));
          counter++;
          list.add('${Task.current.name}$counter');
          if (i + 1 < 3) {
            await f(i + 1, null);
          }
        } finally {
          await m.release();
        }
      } else {
        if (await m.tryAcquire(timeout)) {
          try {
            await Future<void>.delayed(Duration(milliseconds: 50));
            counter++;
            list.add('${Task.current.name}$counter');
            if (i + 1 < 3) {
              await f(i + 1, null);
            }
          } finally {
            await m.release();
          }
        }
      }
    }

    final durations = <Duration?>[
      null,
      Duration(milliseconds: 50),
      Duration(seconds: 1)
    ];
    for (var i = 0; i < 3; i++) {
      final d = durations[i];
      final t = Task.run(name: '$i', () => f(0, d));
      tasks.add(t);
    }

    await Task.whenAll(tasks);

    expect(list, equals(['01', '02', '03', '24', '25', '26']), reason: 'list');
  });
}
