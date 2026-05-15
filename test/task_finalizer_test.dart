@TestOn('vm')
library;

import 'dart:async';
import 'package:multitasking/src/multitasking/task.dart';
import 'package:test/test.dart';

void main() {
  test('Task._finalizer: callback', () async {
    final errors = <Object>[];
    final timeout = Completer<void>();

    runZonedGuarded(() {
      for (var i = 0; i < 5000; i++) {
        // Ignore lints
        // ignore: discarded_futures
        Task.run(() => throw Exception());
      }

      Timer.run(() {
        final memory = <List<int>>[];
        for (var i = 0; i < 150000; i++) {
          memory.add(List<int>.filled(100, i));
        }

        memory.clear();
      });

      Timer(const Duration(milliseconds: 1000), timeout.complete);
    }, (error, stack) {
      errors.add(error);
    });

    await timeout.future;

    expect(errors, isNotEmpty, reason: 'errors');
    expect(errors.first, isA<Exception>(), reason: 'errors.first');
  });
}
