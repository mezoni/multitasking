import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/zoned_work.dart';
import 'package:test/test.dart';

void main() {
  _testZonedWork();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testZonedWork() {
  test('ZonedWork: sync result', () async {
    var count1 = 0;
    var count2 = 0;
    int f() {
      Timer(Duration(milliseconds: 100), () {
        count1++;
      });

      Timer.periodic(Duration(milliseconds: 100), (t) {
        count2++;
        t.cancel();
      });

      return 42;
    }

    Object? error;
    Object? result;
    final work = ZonedWork(f);
    try {
      result = await work.run();
    } catch (e) {
      error = e;
    }

    expect(result, equals(42), reason: 'result');
    expect(error, isNull, reason: 'error');
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    await _delay(200);
    expect(count1, equals(1), reason: 'count1');
    expect(count2, equals(1), reason: 'count2');
  });

  test('ZonedWork: async result', () async {
    var count1 = 0;
    var count2 = 0;
    Future<int> f() async {
      Timer(Duration(milliseconds: 100), () {
        count1++;
      });

      Timer.periodic(Duration(milliseconds: 100), (t) {
        count2++;
        t.cancel();
      });

      return 42;
    }

    Object? error;
    Object? result;
    final work = ZonedWork(f);
    try {
      result = await work.run();
    } catch (e) {
      error = e;
    }

    expect(result, equals(42), reason: 'result');
    expect(error, isNull, reason: 'error');
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    await _delay(200);
    expect(count1, equals(1), reason: 'count1');
    expect(count2, equals(1), reason: 'count2');
  });

  test('ZonedWork: terminate when timer creates timer', () async {
    var count = 0;
    Future<void> f() async {
      late void Function() createTimer;
      createTimer = () {
        count++;
        Timer(Duration(milliseconds: 10), () {
          createTimer();
        });
      };

      createTimer();
    }

    final work = ZonedWork(f);
    final completer = Completer<void>();
    Timer(Duration(milliseconds: 100), () async {
      work.terminate();
      completer.complete();
    });
    await work.run();
    expect(count, greaterThan(0), reason: 'count');
    await completer.future;
    final count2 = count;
    await _delay(200);
    expect(count, count2, reason: 'count');
  });

  test('ZonedWork: terminate when timer creates microtask', () async {
    var count = 0;
    Future<void> f() async {
      late void Function() createTimer;
      createTimer = () {
        count++;
        Timer(Duration(milliseconds: 10), () {
          scheduleMicrotask(createTimer);
        });
      };

      scheduleMicrotask(createTimer);
    }

    final work = ZonedWork(f);
    final completer = Completer<void>();
    Timer(Duration(milliseconds: 100), () async {
      work.terminate();
      completer.complete();
    });
    await work.run();
    expect(count, greaterThan(0), reason: 'count');
    await completer.future;
    final count2 = count;
    await _delay(200);
    expect(count, count2, reason: 'count');
  });

  test('ZonedWork: terminate microtasks', () async {
    var count = 0;
    ZonedWork<void>? work;
    Future<void> f() async {
      void task() {
        count++;
      }

      scheduleMicrotask(task);
      await _delay(0);
      scheduleMicrotask(task);
      scheduleMicrotask(task);
      work?.terminate();
      scheduleMicrotask(task);
      scheduleMicrotask(task);
    }

    Object? error;
    work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, equals(1), reason: 'count');
    await _delay(200);
    expect(count, equals(1), reason: 'count');
  });

  test('ZonedWork: terminate using token', () async {
    var count = 0;
    ZonedWork<void>? work;
    Future<void> f() async {
      final token = Task.token;
      for (var i = 0; i < 10; i++) {
        count++;
        await _delay(50);
        token.throwIfCanceled();
      }
    }

    Object? error;
    final cts = CancellationTokenSource(Duration(milliseconds: 200));
    work = ZonedWork(f, token: cts.token);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, greaterThan(0), reason: 'count');
    final count2 = count;
    await _delay(200);
    expect(count, equals(count2), reason: 'count');
  });

  test('ZonedWork: terminate stream', () async {
    var count = 0;
    Stream<void>? stream;
    Future<void> f() async {
      final completer = Completer<void>();
      unawaited(Zone.root.run(() async {
        stream = Stream.periodic(Duration(milliseconds: 50), (_) {
          count++;
        });
        completer.complete();
      }));

      await completer.future;
      stream!.listen(null);
      await _delay(1000);
    }

    Object? error;
    final work = ZonedWork(f);
    Timer(Duration(milliseconds: 200), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, greaterThan(0), reason: 'count');
    final count2 = count;
    await _delay(200);
    expect(count, count2, reason: 'count');
  });

  test('ZonedWork: terminate awaiting function', () async {
    var count = 0;
    late ZonedWork<void> work;
    Future<void> f1() async {
      count++;
    }

    Future<void> f() async {
      while (true) {
        await f1();
        if (count > 100) {
          // An infinite flow of microtasks (scheduled by the `await` statement)
          // does not allow to use of a timer, since the timer will never fire.
          scheduleMicrotask(work.terminate);
        }
      }
    }

    Object? error;
    work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, greaterThan(0), reason: 'count');
    final count2 = count;
    await _delay(100);
    expect(count, equals(count2), reason: 'count');
  });

  test(
      'ZonedWork: terminate awaiting completer.future (created inside this zone)',
      () async {
    var count = 0;
    late Completer<void> completer;
    Future<void> f() async {
      completer = Completer<void>();
      await completer.future;
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    Timer(Duration(milliseconds: 100), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    completer.complete();
    await _delay(100);
    expect(count, equals(0), reason: 'count');
  });

  test(
      'ZonedWork: terminate awaiting completer.future with error (created inside this zone)',
      () async {
    Object? error1;
    Object? error2;
    late Completer<void> completer;
    Future<void> f() async {
      completer = Completer<void>();
      try {
        await completer.future;
      } catch (e) {
        error2 = e;
      }
    }

    final work = ZonedWork(f);
    Timer(Duration(milliseconds: 100), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error1 = e;
    }

    expect(error1, isA<CancellationException>(), reason: 'error1');
    completer.completeError(Exception());
    await _delay(100);
    expect(error2, isNull, reason: 'error2');
  });

  test(
      'ZonedWork: terminate awaiting completer.future (created outside this zone)',
      () async {
    var count = 0;
    final completer = Completer<void>();
    Future<void> f() async {
      await completer.future;
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    Timer(Duration(milliseconds: 100), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, equals(0), reason: 'count');
    completer.complete();
    await _delay(100);
    expect(count, equals(0), reason: 'count');
  });

  test('ZonedWork: sync error', () async {
    var count1 = 0;
    var count2 = 0;
    var count3 = 0;
    void f() {
      Timer(Duration(milliseconds: 50), () {
        count1++;
      });

      Timer.periodic(Duration(milliseconds: 50), (t) {
        count2++;
      });

      Stream.periodic(Duration(milliseconds: 50), (_) {
        count3++;
      }).listen(null);

      throw Exception();
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    expect(count3, equals(0), reason: 'count3');
    await _delay(200);
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    expect(count3, equals(0), reason: 'count3');
  });

  test('ZonedWork: async error', () async {
    var count1 = 0;
    var count2 = 0;
    var count3 = 0;
    Future<void> f() async {
      Timer(Duration(milliseconds: 50), () {
        count1++;
      });

      Timer.periodic(Duration(milliseconds: 50), (t) {
        count2++;
      });

      Stream.periodic(Duration(milliseconds: 50), (_) {
        count3++;
      }).listen(null);

      throw Exception();
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    expect(count3, equals(0), reason: 'count3');
    await _delay(200);
    expect(count1, equals(0), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    expect(count3, equals(0), reason: 'count3');
  });

  test('ZonedWork: error in timer', () async {
    var count = 0;
    Future<void> f() async {
      Timer(Duration(milliseconds: 50), () {
        throw Exception();
      });

      await _delay(100);
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count, equals(0), reason: 'count');
    await _delay(200);
    expect(count, equals(0), reason: 'count');
  });

  test('ZonedWork: error in stream', () async {
    var count = 0;
    Future<void> f() async {
      Stream.periodic(Duration(milliseconds: 50), (c) {
        return c;
      }).listen((event) {
        count = event;
        if (count == 2) {
          throw Exception();
        }
      });

      await _delay(500);
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count, equals(2), reason: 'count');
    await _delay(200);
    expect(count, equals(2), reason: 'count');
  });

  test('ZonedWork: error in periodic timer', () async {
    var count = 0;
    Future<void> f() async {
      Timer.periodic(Duration(milliseconds: 50), (t) {
        throw Exception();
      });

      await _delay(100);
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count, equals(0), reason: 'count');
    await _delay(200);
    expect(count, equals(0), reason: 'count');
  });

  test('ZonedWork: terminate before run', () async {
    Future<void> f() async {
      while (true) {
        await _delay(100);
      }
    }

    Object? error;
    final work = ZonedWork(f);
    work.terminate();
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('ZonedWork: error in periodic timer', () async {
    var count = 0;
    Future<void> f() async {
      Timer.periodic(Duration(milliseconds: 50), (t) {
        throw Exception();
      });

      await _delay(100);
      count++;
    }

    Object? error;
    final work = ZonedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(count, equals(0), reason: 'count');
    await _delay(200);
    expect(count, equals(0), reason: 'count');
  });

  test('ZonedWork: onExit()', () async {
    var count = 0;
    var onExitCalled = false;
    // `sink.close()` ignored.
    // ignore: close_sinks
    final controller = StreamController<int>.broadcast();
    unawaited(() async {
      for (var i = 0; i < 15; i++) {
        controller.add(i);
        await _delay(100);
      }
    }());

    Future<void> f() async {
      StreamSubscription<int>? subscription;
      if (ZonedWork.current != null) {
        ZonedWork.onExit((work) {
          onExitCalled = true;
          subscription?.cancel().ignore();
        });
      }

      final stream = controller.stream;
      subscription = stream.listen((event) {
        count++;
      });

      await subscription.asFuture<void>();
    }

    Object? error;
    final work = ZonedWork(f);
    Timer(Duration(milliseconds: 200), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, greaterThan(0), reason: 'count');
    expect(count, lessThan(4), reason: 'count');
    expect(onExitCalled, isTrue, reason: 'onExitCalled');
    final count2 = count;
    await _delay(200);
    expect(count, equals(count2), reason: 'count');
    expect(controller.hasListener, isFalse, reason: 'controller.hasListener');
  });

  test('ZonedWork: terminate outer work', () async {
    Object? error;
    var outerCount = 0;
    var innerCount = 0;
    var outerOnExitCalled = false;
    var innerOnExitCalled = false;
    Future<void> inner() async {
      if (ZonedWork.current != null) {
        ZonedWork.onExit((work) {
          innerOnExitCalled = true;
        });
      }

      await _delay(200);
      innerCount++;
    }

    Future<void> outer() async {
      if (ZonedWork.current != null) {
        ZonedWork.onExit((work) {
          outerOnExitCalled = true;
        });
      }

      final work = ZonedWork(inner);
      await work.run();
      await _delay(50);
      outerCount++;
    }

    final work = ZonedWork(outer);
    Timer(Duration(milliseconds: 100), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(outerCount, equals(0), reason: 'outerCount');
    expect(outerOnExitCalled, isTrue, reason: 'outerOnExitCalled');
    await _delay(500);
    expect(innerCount, equals(1), reason: 'innerCount');
    expect(innerOnExitCalled, isTrue, reason: 'innerOnExitCalled');
  });

  test('ZonedWork: current', () async {
    ZonedWork<void>? current1;
    ZonedWork<void>? current2;
    ZonedWork<void>? current3;
    ZonedWork<void>? current4;
    final completer = Completer<void>();

    final outer = ZonedWork(() async {
      current1 = ZonedWork.current;

      final inner = ZonedWork(() async {
        current2 = ZonedWork.current;
        runZoned(() {
          current3 = ZonedWork.current;
          scheduleMicrotask(() {
            current4 = ZonedWork.current;
            completer.complete();
          });
        });
      });

      await inner.run();
    });

    await Future.wait([outer.run(), completer.future]);
    expect(current2, isNot(equals(current1)), reason: 'current2');
    expect(current3, equals(current2), reason: 'current3');
    expect(current4, equals(current2), reason: 'current4');
  });
}
