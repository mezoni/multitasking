import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testaAsCancelable();
  _testaListenWithCancellation();
  _testWithSubscriptionTracking();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testaAsCancelable() {
  var count1 = 0;
  var count2 = 0;
  Object? error;
  final events1 = <SubscriptionEvent>[];
  final events2 = <SubscriptionEvent>[];

  Future<void> f(bool throwIfCanceled, CancellationTokenSource cts) async {
    count1 = 0;
    count2 = 0;
    error = null;
    events1.clear();
    events2.clear();

    Stream<int> gen() async* {
      for (var i = 0; i < 5; i++) {
        count1++;
        yield i;
        await _delay(100);
      }
    }

    final token = cts.token;
    final stream = gen()
        .withSubscriptionTracking(events1.add)
        .asCancelable(token, throwIfCanceled: throwIfCanceled)
        .withSubscriptionTracking(events2.add);

    final c = Completer<void>();
    stream.listen(
      (event) {
        count2++;
      },
      onDone: c.complete,
      onError: (Object e) {
        error = e;
      },
    );

    await c.future;
    await _delay(500);
  }

  test('StreamExtension.asCancelable(): cancel before', () async {
    for (final throwIfCanceled in [true, false]) {
      final cts = CancellationTokenSource();
      cts.cancel();
      await f(throwIfCanceled, cts);

      throwIfCanceled
          ? expect(error, isA<TaskCanceledException>(), reason: 'error')
          : expect(error, isNull, reason: 'error');
      expect(count1, equals(0), reason: 'count1');
      expect(count2, equals(0), reason: 'count2');
      expect(events1, <SubscriptionEvent>[], reason: 'events1');
      expect(
          events2,
          [
            SubscriptionEvent.start,
            if (throwIfCanceled) SubscriptionEvent.error,
            SubscriptionEvent.done,
          ],
          reason: 'events2');
    }
  });

  test('StreamExtension.asCancelable(): cancel immediately', () async {
    for (final throwIfCanceled in [true, false]) {
      final cts = CancellationTokenSource(const Duration());
      await f(throwIfCanceled, cts);

      throwIfCanceled
          ? expect(error, isA<TaskCanceledException>(), reason: 'error')
          : expect(error, isNull, reason: 'error');
      expect(count1, greaterThanOrEqualTo(2), reason: 'count1');
      expect(count2, greaterThanOrEqualTo(1), reason: 'count2');
      expect(
          events1,
          <SubscriptionEvent>[
            SubscriptionEvent.start,
            SubscriptionEvent.cancel,
          ],
          reason: 'events1');
      expect(
          events2,
          [
            SubscriptionEvent.start,
            if (throwIfCanceled) SubscriptionEvent.error,
            SubscriptionEvent.done,
          ],
          reason: 'events2');
    }
  });

  test('StreamExtension.asCancelable(): cancel between', () async {
    for (final throwIfCanceled in [true, false]) {
      final cts = CancellationTokenSource(const Duration(milliseconds: 150));
      await f(throwIfCanceled, cts);

      throwIfCanceled
          ? expect(error, isA<TaskCanceledException>(), reason: 'error')
          : expect(error, isNull, reason: 'error');
      expect(count1, greaterThanOrEqualTo(3), reason: 'count1');
      expect(count2, greaterThanOrEqualTo(2), reason: 'count2');
      expect(count1, lessThan(5), reason: 'count1');
      expect(count2, lessThan(5), reason: 'count2');
      expect(
          events1,
          <SubscriptionEvent>[
            SubscriptionEvent.start,
            SubscriptionEvent.cancel,
          ],
          reason: 'events1');
      expect(
          events2,
          [
            SubscriptionEvent.start,
            if (throwIfCanceled) SubscriptionEvent.error,
            SubscriptionEvent.done,
          ],
          reason: 'events2');
    }
  });

  test('StreamExtension.asCancelable(): cancel after', () async {
    for (final throwIfCanceled in [true, false]) {
      final cts = CancellationTokenSource(const Duration(milliseconds: 600));
      await f(throwIfCanceled, cts);

      expect(error, isNull, reason: 'error');
      expect(count1, equals(5), reason: 'count1');
      expect(count2, equals(5), reason: 'count2');
      expect(
          events1,
          <SubscriptionEvent>[
            SubscriptionEvent.start,
            SubscriptionEvent.done,
          ],
          reason: 'events1');
      expect(
          events2,
          [
            SubscriptionEvent.start,
            SubscriptionEvent.done,
          ],
          reason: 'events2');
    }
  });
}

void _testaListenWithCancellation() {
  test('StreamExtension.listenWithCancellation(): subscription.cancel()',
      () async {
    var count1 = 0;
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        count1++;
        yield i;
        await _delay(100);
      }
    }

    final cts = CancellationTokenSource();
    final token = cts.token;
    final events = <SubscriptionEvent>[];
    var count2 = 0;
    final sub = gen()
        .withSubscriptionTracking(events.add)
        .listenWithCancellation(token: token, (event) {
      count2++;
    });
    await sub.cancel();
    await _delay(400);
    expect(count1, equals(1), reason: 'count1');
    expect(count2, equals(0), reason: 'count2');
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.cancel],
        reason: 'events');
  });
}

void _testWithSubscriptionTracking() {
  final error = Exception('Error');
  test('StreamExtension.withSubscriptionTracking(): pause/resume/cancel',
      () async {
    final events = <SubscriptionEvent>[];
    final stream = Stream.periodic(Duration(milliseconds: 100), (count) {
      return count;
    }).withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    final sub = stream.listen((_) {});
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await _delay(100);
    sub.pause();
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.pause],
        reason: 'events');
    await _delay(100);
    sub.resume();
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.pause,
          SubscriptionEvent.resume
        ],
        reason: 'events');
    await sub.cancel();
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.pause,
          SubscriptionEvent.resume,
          SubscriptionEvent.cancel
        ],
        reason: 'events');
  });

  test('StreamExtension.withSubscriptionTracking(): done', () async {
    final events = <SubscriptionEvent>[];
    final completer = Completer<void>();
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        yield i;
        await Future<void>.delayed(Duration(milliseconds: 100));
      }

      completer.complete();
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {});
    expect(events, [SubscriptionEvent.start], reason: 'state');
    await completer.future;
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.done],
        reason: 'events');
  });

  test('StreamExtension.withSubscriptionTracking(): onDone', () async {
    final events = <SubscriptionEvent>[];
    final completer = Completer<void>();
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        yield i;
        await Future<void>.delayed(Duration(milliseconds: 100));
      }

      completer.complete();
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {}, onDone: () {
      //
    }).onDone(null);
    expect(events, [SubscriptionEvent.start], reason: 'state');
    await completer.future;
    await _delay(200);
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.done],
        reason: 'events');
  });

  test('StreamExtension.withSubscriptionTracking(): error (e, s)', () async {
    final events = <SubscriptionEvent>[];
    final completer = Completer<void>();
    Stream<int> gen() async* {
      try {
        for (var i = 0; i < 3; i++) {
          if (i == 2) {
            throw error;
          } else {
            yield i;
          }

          await Future<void>.delayed(Duration(milliseconds: 100));
        }
      } finally {
        completer.complete();
      }
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {}, onError: (Object e, __) {
      expect(e, error, reason: 'error');
    });
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await completer.future;
    await _delay(200);
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.error,
          SubscriptionEvent.done
        ],
        reason: 'events');
  });

  test('StreamExtension.withSubscriptionTracking(): error (e)', () async {
    final events = <SubscriptionEvent>[];
    final completer = Completer<void>();
    Stream<int> gen() async* {
      try {
        for (var i = 0; i < 3; i++) {
          if (i == 2) {
            throw error;
          } else {
            yield i;
          }

          await Future<void>.delayed(Duration(milliseconds: 100));
        }
      } finally {
        completer.complete();
      }
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {}, onError: (Object e) {
      expect(e, error, reason: 'error');
    });
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await completer.future;
    await _delay(200);
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.error,
          SubscriptionEvent.done
        ],
        reason: 'events');
  });

  test('StreamExtension.withSubscriptionTracking(): onError', () async {
    final events = <SubscriptionEvent>[];
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        if (i == 2) {
          throw error;
        } else {
          yield i;
        }

        await Future<void>.delayed(Duration(milliseconds: 100));
      }
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {}, onError: (Object e) {
      expect(e, error, reason: 'error');
    }).onError(null);
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await _delay(500);
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.error,
          SubscriptionEvent.done
        ],
        reason: 'events');
  });
}
