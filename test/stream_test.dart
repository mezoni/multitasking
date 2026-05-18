import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testCancelableStreamFactory();
  _testStreamAsCancelable();
  _testTerminationTransformer();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testCancelableStreamFactory() {
  var count = 0;
  Stream<int> gen(CancellationToken token) async* {
    count = 0;
    for (var i = 0; i < 3; i++) {
      yield i;
      await _delay(100);
    }
  }

  test('CancelableStreamFactory: cancel', () async {
    final stream = CancelableStreamFactory.fromGenerator(gen);
    final cts = CancellationTokenSource();
    Object? error;
    try {
      await for (final event in stream.asCancelable(cts.token)) {
        if (event == 1) {
          cts.cancel();
        }
      }
    } catch (e) {
      error = e;
    }

    final count2 = count;
    await _delay(200);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count, equals(count2), reason: 'count');
  });
}

void _testStreamAsCancelable() {
  const count = 5;

  var count1 = 0;
  var count2 = 0;
  Object? error;

  Future<void> f({
    int? cancelValue,
    required CancellationTokenSource cts,
    PauseToken? pauseToken,
    Duration? timeout,
  }) async {
    count1 = 0;
    count2 = 0;
    error = null;
    Stream<int> gen() async* {
      for (var i = 1; i <= count; i++) {
        count1 = i;
        yield i;
        await _delay(100);
      }
    }

    final token = cts.token;
    final stream = gen().asCancelable(
      token,
      pauseToken: pauseToken,
      timeout: timeout,
    );
    try {
      await for (final event in stream) {
        count2 = event;
        if (event == cancelValue) {
          cts.cancel();
        }
      }
    } catch (e) {
      error = e;
    }
  }

  test('StreamExtension.asCancelable(): cancel before', () async {
    final cts = CancellationTokenSource();
    cts.cancel();
    await f(cts: cts);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel (paused) before', () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    cts.cancel();
    await pts.pause();
    await f(cts: cts);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel before with timeout', () async {
    final cts = CancellationTokenSource();
    cts.cancel();
    await f(cts: cts, timeout: Duration(milliseconds: 100));
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel immediately', () async {
    final cts = CancellationTokenSource(const Duration());
    await f(cts: cts);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel (paused) immediately', () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    Timer(Duration.zero, () async {
      await pts.pause();
      cts.cancel();
    });
    await f(cts: cts);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel between', () async {
    final cts = CancellationTokenSource();
    await f(cancelValue: 2, cts: cts);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel (paused)  between', () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    Timer(Duration(milliseconds: 100), () async {
      await pts.pause();
      cts.cancel();
    });
    await f(cts: cts, pauseToken: pts.token);
    expect(error, isA<CancellationException>(), reason: 'error');
    expect(count1, lessThan(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): cancel after', () async {
    final cts = CancellationTokenSource();
    await f(cts: cts);
    cts.cancel();
    expect(error, isNull, reason: 'error');
    expect(count1, equals(count), reason: 'count1');
    expect(count2, lessThanOrEqualTo(count1), reason: 'count2');
  });

  test('StreamExtension.asCancelable(): blockOnCancel', () async {
    for (final blockOnCancel in [true, false]) {
      final cts = CancellationTokenSource();
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      var value1 = 0;
      var value2 = 0;

      Stream<int> gen() async* {
        await completer1.future;
        value1 = 1;
        yield 0;
      }

      unawaited(() async {
        Object? error;
        try {
          final stream =
              gen().asCancelable(cts.token, blockOnCancel: blockOnCancel);
          await stream.listen(
            (event) {
              value2 = event;
            },
            cancelOnError: true,
          ).asFuture<void>();
        } catch (e) {
          error = e;
        }

        expect(error, isA<CancellationException>(), reason: 'error');
        expect(value1, equals(blockOnCancel ? 1 : 0), reason: 'value1');
        expect(value2, equals(0), reason: 'value2');
        if (!blockOnCancel) {
          completer1.complete();
        }

        await _delay(0);
        expect(value1, equals(1), reason: 'value1');
        expect(value2, equals(0), reason: 'value2');
        completer2.complete();
      }());

      cts.cancel();
      await _delay(100);
      if (blockOnCancel) {
        completer1.complete();
      }

      await completer2.future;
    }
  });

  test('StreamExtension.asCancelable(): timeout before first', () async {
    final s1 = Stream<void>.periodic(Duration(milliseconds: 100));
    final cts = CancellationTokenSource();
    final s2 = s1.asCancelable(
      cts.token,
      timeout: Duration(milliseconds: 50),
    );
    Object? error;
    cts.cancelAfter(Duration(milliseconds: 200));
    try {
      await for (final _ in s2) {
        //
      }
    } catch (e) {
      error = e;
    }

    expect(error, isA<TimeoutException>(), reason: 'error');
  });

  test('StreamExtension.asCancelable(): timeout after first', () async {
    Stream<int> gen() async* {
      await _delay(10);
      yield 1;
      await _delay(150);
      yield 2;
    }

    final s1 = gen();
    final cts = CancellationTokenSource();
    final s2 = s1.asCancelable(
      cts.token,
      timeout: Duration(milliseconds: 50),
    );
    Object? error;
    var value = 0;
    cts.cancelAfter(Duration(milliseconds: 200));
    try {
      await for (final event in s2) {
        value = event;
      }
    } catch (e) {
      error = e;
    }

    expect(error, isA<TimeoutException>(), reason: 'error');
    expect(value, equals(1), reason: 'value');
  });

  test('StreamExtension.asCancelable(): timeout when paused', () async {
    Stream<int> gen() async* {
      await _delay(10);
      yield 1;
      await _delay(10);
      yield 2;
    }

    final s1 = gen();
    final cts = CancellationTokenSource();
    final s2 = s1.asCancelable(
      cts.token,
      timeout: Duration(milliseconds: 50),
    );
    Object? error;
    var value = 0;
    try {
      await for (final event in s2) {
        value = event;
        await _delay(100);
      }
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(value, equals(2), reason: 'value');
  });

  test('StreamExtension.asCancelable(): timeout when paused using token',
      () async {
    const period = 100;
    const timeout = period * 2;
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    var stream = Stream.periodic(Duration(milliseconds: period), (tick) {
      return tick;
    });
    stream = stream.asCancelable(
      cts.token,
      pauseToken: pts.token,
      timeout: Duration(milliseconds: timeout),
    );
    await pts.pause();
    Timer(Duration(microseconds: timeout), pts.resume);
    Timer(Duration(microseconds: timeout * 2), cts.cancel);
    Object? error;
    try {
      await stream.listen(null).asFuture<void>();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('StreamExtension.asCancelable(): timeout <= 0', () async {
    final cts = CancellationTokenSource();
    var stream = Stream.periodic(Duration(milliseconds: 100), (tick) {
      return tick;
    });

    Object? error;
    try {
      stream = stream.asCancelable(
        cts.token,
        timeout: Duration(milliseconds: 0),
      );
    } catch (e) {
      error = e;
    }

    expect(error, isA<ArgumentError>(), reason: 'error');
  });

  test('StreamExtension.asCancelable(): timeout when paused', () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    var stream = Stream.periodic(Duration(milliseconds: 100), (tick) {
      return tick;
    });
    stream = stream.asCancelable(
      cts.token,
      pauseToken: pts.token,
      timeout: Duration(milliseconds: 200),
    );

    Object? error;
    try {
      await for (final event in stream) {
        if (event == 1) {
          Timer(Duration(milliseconds: 300), pts.resume);
          await pts.pause();
        } else if (event == 3) {
          break;
        }
      }
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
  });

  Stream<int> gen() async* {
    for (var i = 1; i < 10; i++) {
      yield i;
      await _delay(100);
    }
  }

  test('StreamExtension.asCancelable(): pause many times, resume at one time',
      () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    var count = 0;
    final sub =
        gen().asCancelable(cts.token, pauseToken: pts.token).listen((event) {
      count = event;
    });

    var count2 = count;
    await pts.pause();
    await pts.pause();
    await pts.pause();
    await pts.pause();
    await pts.pause();
    count2 = count;
    await _delay(200);
    expect(count, equals(count2), reason: 'count');
    await pts.resume();
    await _delay(200);
    expect(count, greaterThan(count2), reason: 'count');
    await sub.cancel();
  });

  test('StreamExtension.asCancelable(): pause/resume', () async {
    final cts = CancellationTokenSource();
    final pts = PauseTokenSource();
    var count = 0;
    gen().asCancelable(cts.token, pauseToken: pts.token).listen((event) {
      count = event;
    });

    var count2 = 0;
    await pts.pause();
    count2 = count;
    await _delay(200);
    expect(count, equals(count2), reason: 'count');
    await pts.resume();
    count2 = count;
    await _delay(200);
    expect(count, greaterThan(count2), reason: 'count');

    await pts.pause();
    count2 = count;
    await _delay(200);
    expect(count, equals(count2), reason: 'count');
    await pts.resume();
    count2 = count;
    await _delay(200);
    expect(count, greaterThan(count2), reason: 'count');
  });
}

void _testTerminationTransformer() {
  var onCancel = false;
  var onError = false;
  var onSuccess = false;
  var onTerminate = false;
  Object? handledError;

  Stream<T> transform<T>(Stream<T> stream) {
    onCancel = false;
    onSuccess = false;
    onError = false;
    onTerminate = false;
    handledError = null;

    return stream.handleTermination(
      () {
        onTerminate = true;
      },
      onCancel: () {
        onCancel = true;
      },
      onError: (e, s) {
        onError = true;
        handledError = e;
      },
      onDone: () {
        onSuccess = true;
      },
    );
  }

  test('CancelableStreamFactory: cancel', () async {
    final values = <int>[];
    final s1 = Stream.fromIterable([1, 2, 3]);
    final s2 = transform(s1);
    await for (final event in s2) {
      values.add(event);
      if (event == 2) {
        break;
      }
    }

    expect(handledError, isNull, reason: 'handledError');
    expect(onCancel, isTrue, reason: 'onCancel');
    expect(onError, isFalse, reason: 'onError');
    expect(onSuccess, isFalse, reason: 'onSuccess');
    expect(onTerminate, isTrue, reason: 'onTerminate');
    expect(values, equals([1, 2]), reason: 'error');
  });

  test('CancelableStreamFactory: done', () async {
    final values = <int>[];
    final s1 = Stream.fromIterable([1, 2, 3]);
    final s2 = transform(s1);
    await for (final event in s2) {
      values.add(event);
    }

    expect(handledError, isNull, reason: 'handledError');
    expect(onCancel, isFalse, reason: 'onCancel');
    expect(onError, isFalse, reason: 'onError');
    expect(onSuccess, isTrue, reason: 'onSuccess');
    expect(onTerminate, isTrue, reason: 'onTerminate');
    expect(values, equals([1, 2, 3]), reason: 'error');
  });

  test('CancelableStreamFactory: error', () async {
    Iterable<int> gen() sync* {
      for (var i = 1; i < 3; i++) {
        yield i;
      }

      throw Exception();
    }

    final values = <int>[];
    final s1 = Stream.fromIterable(gen());
    final s2 = transform(s1);
    Object? error;
    try {
      await for (final event in s2) {
        values.add(event);
      }
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(handledError, isA<Exception>(), reason: 'handledError');
    expect(onCancel, isFalse, reason: 'onCancel');
    expect(onError, isTrue, reason: 'onError');
    expect(onSuccess, isFalse, reason: 'onSuccess');
    expect(onTerminate, isTrue, reason: 'onTerminate');
    expect(values, equals([1, 2]), reason: 'error');
  });

  test('CancelableStreamFactory: many errors', () async {
    final controller = StreamController<int>();
    final s1 = controller.stream;
    final s2 = transform(s1);
    Object? error;
    s2.listen(null, onError: (Object? e) {
      error = e;
    });

    controller.addError(Exception());
    await _delay(100);
    expect(handledError, isA<Exception>(), reason: 'handledError');
    expect(error, isA<Exception>(), reason: 'error');
    expect(onCancel, isFalse, reason: 'onCancel');
    expect(onError, isTrue, reason: 'onError');
    expect(onSuccess, isFalse, reason: 'onSuccess');
    expect(onTerminate, isFalse, reason: 'onTerminate');

    controller.addError(StateError(''));
    await _delay(100);
    expect(handledError, isA<StateError>(), reason: 'handledError');
    expect(error, isA<StateError>(), reason: 'error');
    expect(onCancel, isFalse, reason: 'onCancel');
    expect(onError, isTrue, reason: 'onError');
    expect(onSuccess, isFalse, reason: 'onSuccess');
    expect(onTerminate, isFalse, reason: 'onTerminate');

    onError = false;
    await controller.close();
    await _delay(100);
    expect(handledError, isA<StateError>(), reason: 'handledError');
    expect(error, isA<StateError>(), reason: 'error');
    expect(onCancel, isFalse, reason: 'onCancel');
    expect(onError, isFalse, reason: 'onError');
    expect(onSuccess, isTrue, reason: 'onSuccess');
    expect(onTerminate, isTrue, reason: 'onTerminate');
  });
}
