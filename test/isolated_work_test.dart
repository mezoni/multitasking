@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/isolated_work.dart';
import 'package:test/test.dart';

void main() {
  _testIsolatedWork();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testIsolatedWork() {
  test('IsolatedWork: terminate(force: true)', () async {
    void f() {
      while (true) {}
    }

    Object? error;
    final work = IsolatedWork(f);
    Timer(Duration(milliseconds: 500), () {
      work.terminate(force: true);
    });
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolatedWork: terminate(force: false)', () async {
    Future<void> f() async {
      while (true) {
        await _delay(100);
      }
    }

    Object? error;
    final work = IsolatedWork(f);
    Timer(Duration(milliseconds: 500), work.terminate);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolatedWork: terminate using token', () async {
    Future<void> f() async {
      final token = Task.token;
      while (true) {
        await _delay(100);
        token.throwIfCanceled();
      }
    }

    Object? error;
    final cts = CancellationTokenSource();
    final work = IsolatedWork(f, token: cts.token);
    Timer(Duration(milliseconds: 500), cts.cancel);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolatedWork: terminate before run', () async {
    Future<void> f() async {
      while (true) {
        await _delay(100);
      }
    }

    Object? error;
    final work = IsolatedWork(f);
    work.terminate();
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolatedWork: terminate using token before run', () async {
    Future<void> f() async {
      final token = Task.token;
      while (true) {
        await _delay(100);
        token.throwIfCanceled();
      }
    }

    Object? error;
    final cts = CancellationTokenSource();
    cts.cancel();
    final work = IsolatedWork(f, token: cts.token);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
  });

  test('IsolatedWork: sync result', () async {
    List<int> f(List<int> result) {
      return result;
    }

    final list = [1, 2, 3];
    final work = IsolatedWork(() => f(list));
    final result = await work.run();
    expect(result, equals(list), reason: 'result');
  });

  test('IsolatedWork: async result', () async {
    Future<List<int>> f(List<int> result) async {
      return result;
    }

    final list = [1, 2, 3];
    final work = IsolatedWork(() => f(list));
    final result = await work.run();
    expect(result, equals(list), reason: 'result');
  });

  test('IsolatedWork: withArgument()', () async {
    List<int> f(List<int> result) {
      return result;
    }

    final list = [1, 2, 3];
    final work = IsolatedWork.withArgument(list, f);
    final result = await work.run();
    expect(result, equals(list), reason: 'result');
  });

  test('IsolatedWork: sync error', () async {
    void f() {
      throw Exception();
    }

    Object? error;
    final work = IsolatedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, equals('Exception'), reason: 'result');
  });

  test('IsolatedWork: async error', () async {
    Future<void> f() async {
      throw Exception();
    }

    Object? error;
    final work = IsolatedWork(f);
    try {
      await work.run();
    } catch (e) {
      error = e;
    }

    expect(error, equals('Exception'), reason: 'result');
  });

  test('IsolatedWork: timer', () async {
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
    final work = IsolatedWork(f, token: cts.token);
    unawaited(() async {
      result = await work.run();
    }());

    await _delay(1000);
    expect(result, equals(null), reason: 'result');
    cts.cancel();
    await _delay(100);
    expect(result, equals(42), reason: 'result');
  });

  test('IsolatedWork: Isolate.exit()', () async {
    void f() {
      Isolate.exit();
    }

    Object? error;
    final comp = IsolatedWork(f);
    try {
      await comp.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<StateError>(), reason: 'result');
  });

  test('IsolatedWork: run twice', () async {
    Future<void> f() async {
      await _delay(250);
    }

    Object? error;
    final comp = IsolatedWork(f);
    try {
      unawaited(comp.run());
      await _delay(100);
      await comp.run();
    } catch (e) {
      error = e;
    }

    expect(error, isA<StateError>(), reason: 'result');
  });
}
