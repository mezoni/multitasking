import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:test/test.dart';

void main() {
  _test();
}

void _test() {
  test('CancellationException: toString()', () {
    final object = CancellationException();
    expect(object.toString(), equals('CancellationException'),
        reason: 'toString()');
  });

  test('CancellationException: toString() with message', () {
    final object = CancellationException('Error');
    expect(object.toString(), equals('CancellationException: Error'),
        reason: 'toString()');
  });

  test('AggregateError: empty exception list', () {
    Object? error;
    try {
      AggregateError([]);
    } catch (e) {
      error = e;
    }

    expect(error, isA<ArgumentError>(), reason: 'error');
  });

  test('AggregateError: exceptions', () {
    final object = AggregateError([
      AsyncError(Exception(), StackTrace.current),
      AsyncError(CancellationException(), StackTrace.current),
    ]);

    final exceptions = object.exceptions;
    expect(exceptions.length, equals(2), reason: 'exceptions.length');
    final exception1 = exceptions[0];
    final exception2 = exceptions[1];
    expect(exception1.error, isA<Exception>(), reason: 'exception1.error');
    expect(exception2.error, isA<CancellationException>(),
        reason: 'exception2.error');
  });

  test('AggregateError: toString()', () {
    final object = AggregateError([
      AsyncError(Exception(), StackTrace.current),
      AsyncError(CancellationException(), StackTrace.current),
    ]);

    expect(
        object.toString(),
        equals(
            'AggregateError: One or more errors occurred. (Exception) (CancellationException)'),
        reason: 'toString()');
  });

  test('TaskStateError: toString()', () {
    final object = TaskStateError();
    expect(object.toString(), equals('TaskStateError'), reason: 'toString()');
  });

  test('TaskStateError: toString() with message', () {
    final object = TaskStateError('Error');
    expect(object.toString(), equals('TaskStateError: Error'),
        reason: 'toString()');
  });
}
