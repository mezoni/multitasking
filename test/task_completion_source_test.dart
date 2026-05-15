import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _testTaskCompletionSource();
}

Future<void> _delay(int milliseconds) {
  return Future.delayed(Duration(milliseconds: milliseconds));
}

void _testTaskCompletionSource() {
  test('TaskCompletionSource.setCanceled()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), tcs.setCanceled);
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<CancellationException>(),
        reason: 'exception.error');
  });

  test('TaskCompletionSource.setCanceled(): call twice', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Object? error;
    try {
      tcs.setCanceled();
      tcs.setCanceled();
    } catch (e) {
      error = e;
    }

    await _delay(50);

    expect(error, isA<TaskStateError>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<CancellationException>(),
        reason: 'exception.error');
  });

  test('TaskCompletionSource.setError()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), () {
      tcs.setError(Exception(), StackTrace.current);
    });
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<Exception>(), reason: 'exception.error');
  });

  test('TaskCompletionSource.setError(): call twice', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Object? error;
    try {
      tcs.setError(Exception(), StackTrace.current);
      tcs.setError(StateError(''), StackTrace.current);
    } catch (e) {
      error = e;
    }

    await _delay(50);

    expect(error, isA<TaskStateError>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<Exception>(), reason: 'exception.error');
  });

  test('TaskCompletionSource.setResult()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), () {
      tcs.setResult(42);
    });
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(task.status, equals(TaskStatus.succeeded), reason: 'status');
    expect(task.result, equals(42), reason: 'result');
  });

  test('TaskCompletionSource.setResult(): call twice', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Object? error;
    try {
      tcs.setResult(42);
      tcs.setResult(42 * 2);
    } catch (e) {
      error = e;
    }

    await _delay(50);

    expect(error, isA<TaskStateError>(), reason: 'error');
    expect(task.status, equals(TaskStatus.succeeded), reason: 'status');
    expect(task.result, equals(42), reason: 'result');
  });

  test('TaskCompletionSource.trySetCanceled()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), () {
      tcs.trySetCanceled();
      tcs.trySetCanceled();
    });
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<CancellationException>(), reason: 'error');
    expect(task.status, equals(TaskStatus.canceled), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<CancellationException>(),
        reason: 'exception.error');
  });

  test('TaskCompletionSource.trySetError()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), () {
      tcs.trySetError(Exception(), StackTrace.current);
      tcs.trySetError(StateError(''), StackTrace.current);
    });
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isA<Exception>(), reason: 'error');
    expect(task.status, equals(TaskStatus.failed), reason: 'status');
    expect(task.exception, isA<AsyncError>(), reason: 'exception');
    expect(task.exception!.error, isA<Exception>(), reason: 'exception.error');
  });

  test('TaskCompletionSource.trySetResult()', () async {
    final tcs = TaskCompletionSource<int>();
    final task = tcs.task;
    Timer(Duration(milliseconds: 100), () {
      tcs.trySetResult(42);
      tcs.trySetResult(42 * 2);
    });
    Object? error;
    try {
      await task;
    } catch (e) {
      error = e;
    }

    expect(error, isNull, reason: 'error');
    expect(task.status, equals(TaskStatus.succeeded), reason: 'status');
    expect(task.result, equals(42), reason: 'result');
  });
}
