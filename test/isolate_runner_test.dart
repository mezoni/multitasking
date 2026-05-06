import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testIsolateRunner();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testIsolateRunner() {
  test('IsolateRunner: cancel(immediate: true)', () async {
    void f() {
      while (true) {}
    }

    Object? error;
    final runner = IsolateRunner(f);
    Timer(Duration(milliseconds: 500), () {
      runner.terminate(immediate: true);
    });
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolateRunner: cancel(immediate: false)', () async {
    Future<void> f() async {
      while (true) {
        await _delay(100);
      }
    }

    Object? error;
    final runner = IsolateRunner(f);
    Timer(Duration(milliseconds: 500), runner.terminate);
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolateRunner: cancel using token', () async {
    Future<void> f() async {
      final token = Task.token;
      while (true) {
        await _delay(100);
        token.throwIfCanceled();
      }
    }

    Object? error;
    final cts = CancellationTokenSource();
    final runner = IsolateRunner(f, token: cts.token);
    Timer(Duration(milliseconds: 500), cts.cancel);
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolateRunner: sync result', () async {
    int f(int result) {
      return result;
    }

    final runner = IsolateRunner(() => f(42));
    final result = await runner.run();
    expect(result, equals(42), reason: 'result');
  });

  test('IsolateRunner: async result', () async {
    Future<int> f(int result) async {
      return result;
    }

    final runner = IsolateRunner(() => f(42));
    final result = await runner.run();
    expect(result, equals(42), reason: 'result');
  });

  test('IsolateRunner: sync error', () async {
    void f() {
      throw Exception();
    }

    Object? error;
    final runner = IsolateRunner(f);
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, equals('Exception'), reason: 'result');
  });

  test('IsolateRunner: async error', () async {
    Future<void> f() async {
      throw Exception();
    }

    Object? error;
    final runner = IsolateRunner(f);
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, equals('Exception'), reason: 'result');
  });

  test('IsolateRunner: timer', () async {
    Future<int> f() async {
      final timer = Timer(Duration(seconds: 25), () {});
      final token = Task.token;
      while (true) {
        await _delay(25);
        if (token.isCanceled) {
          timer.cancel();
          break;
        }
      }

      return 42;
    }

    Object? result;
    final cts = CancellationTokenSource();
    final runner = IsolateRunner(f, token: cts.token);
    unawaited(() async {
      result = await runner.run();
    }());

    await _delay(1000);
    expect(result, equals(null), reason: 'result');
    cts.cancel();
    await _delay(100);
    expect(result, equals(42), reason: 'result');
  });

  test('IsolateRunner: Isolate.exit()', () async {
    void f() {
      Isolate.exit();
    }

    Object? error;
    final runner = IsolateRunner(f);
    try {
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<RemoteError>(), reason: 'result');
  });

  test('IsolateRunner: run twice', () async {
    Future<void> f() async {
      await _delay(250);
    }

    Object? error;
    final runner = IsolateRunner(f);
    try {
      unawaited(runner.run());
      await _delay(100);
      await runner.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<StateError>(), reason: 'result');
  });
}
