import 'dart:async';
import 'dart:collection';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';
import 'package:multitasking/synchronization/condition_variable.dart';
import 'package:multitasking/synchronization/reentrant_lock.dart';
import 'package:test/test.dart';

void main() {
  _testReentrantLock();
  _testBinarySemaphore();
  _testConditionVariable();
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
          await _delay(100);
          total++;
          count++;
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
    expect(count, 0, reason: 'count != 0');
    expect(max, 1, reason: 'max != 1');
    expect(total, futures.length, reason: 'total != ${futures.length}');
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
            await _delay(100);
            total++;
            count++;
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
              await _delay(100);
              total++;
              count++;
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
    expect(count, 0, reason: 'count != 0');
    expect(max, 1, reason: 'max != 1');
    expect(total, futures.length ~/ 2,
        reason: 'total != ${futures.length ~/ 2}');
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
            await _delay(100);
            total++;
            count++;
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
    expect(count, 0, reason: 'count != 0');
    expect(max, 1, reason: 'max != 1');
    expect(total, futures.length ~/ 2,
        reason: 'total != ${futures.length ~/ 2}');
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
    expect(products.isEmpty, true, reason: 'products.isNotEmpty');
    expect(produced, 5, reason: 'produced != 5');
    expect(consumed, 5, reason: 'consumed != 5');
  });
}

void _testReentrantLock() {
  test('ReentrantLock:', () async {
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

    await Task.waitAll(tasks);

    expect(list, ['01', '02', '03', '14', '15', '16', '27', '28', '29'],
        reason: 'mutex does not works');
  });
}
