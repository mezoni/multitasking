import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  const interval = 50;
  const timeout = interval * 3;

  Stream<int> gen() async* {
    for (var i = 0; i < 5; i++) {
      final int delay;
      if (i < 4) {
        delay = interval;
      } else {
        print('Oh, long work...');
        delay = timeout;
      }

      await Future<void>.delayed(Duration(milliseconds: delay));
      yield i;
    }
  }

  final cts = CancellationTokenSource();
  final stream = gen().asCancelable(
    cts.token,
    timeout: Duration(milliseconds: timeout),
  );

  try {
    await for (final event in stream) {
      print(event);
      // Performing the work longer than the timeout
      await Future<void>.delayed(const Duration(milliseconds: timeout * 2));
    }
  } catch (e) {
    print('Error: $e');
  }
}
