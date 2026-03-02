import 'package:multitasking/synchronization/binary_semaphore.dart';
import 'package:test/test.dart';

void main() {
  _testBinarySemaphore();
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

  test('BinarySemaphore.tryAcquire(): Without duration', () async {
    final sem = BinarySemaphore();
    var count = 0;
    var max = 0;
    var total = 0;
    final futures = <Future<void>>[];
    final timeouts = <Duration?>[];
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 0));
    timeouts.add(null);
    timeouts.add(Duration(milliseconds: 0));
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
}
