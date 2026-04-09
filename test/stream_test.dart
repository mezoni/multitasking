import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testWithSubscriptionTracking();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testWithSubscriptionTracking() {
  final error = Exception('Error');
  test('StreamExtension: withSubscriptionTracking(), pause/resume/cancel',
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

  test('StreamExtension: withSubscriptionTracking(), done', () async {
    final events = <SubscriptionEvent>[];
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        yield i;
        await Future<void>.delayed(Duration(milliseconds: 100));
      }
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {});
    expect(events, [SubscriptionEvent.start], reason: 'state');
    await _delay(400);
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.done],
        reason: 'events');
  });

  test('StreamExtension: withSubscriptionTracking(), onDone', () async {
    final events = <SubscriptionEvent>[];
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        yield i;
        await Future<void>.delayed(Duration(milliseconds: 100));
      }
    }

    final stream = gen().withSubscriptionTracking(events.add);

    expect(events, <SubscriptionEvent>[], reason: 'events');
    stream.listen((_) {}, onDone: () {
      //
    }).onDone(null);
    expect(events, [SubscriptionEvent.start], reason: 'state');
    await _delay(400);
    expect(events, [SubscriptionEvent.start, SubscriptionEvent.done],
        reason: 'events');
  });

  test('StreamExtension: withSubscriptionTracking(), error (e, s)', () async {
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
    stream.listen((_) {}, onError: (Object e, __) {
      expect(e, error, reason: 'error');
    });
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await _delay(400);
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.error,
          SubscriptionEvent.done
        ],
        reason: 'events');
  });

  test('StreamExtension: withSubscriptionTracking(), error (e)', () async {
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
    });
    expect(events, [SubscriptionEvent.start], reason: 'events');
    await _delay(400);
    expect(
        events,
        [
          SubscriptionEvent.start,
          SubscriptionEvent.error,
          SubscriptionEvent.done
        ],
        reason: 'events');
  });

  test('StreamExtension: withSubscriptionTracking(), onError', () async {
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
    await _delay(400);
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
