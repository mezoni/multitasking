import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  const interval = 50;
  const timeout = interval * 3;

  Stream<int> gen(CancellationToken token) async* {
    for (var i = 0; i < 2; i++) {
      _message('Begin work');
      final int delay;
      if (i == 0) {
        delay = interval;
      } else {
        _message('Oh, long work...');
        delay = timeout * 5;
      }

      try {
        // For demonstration purposes only.
        // The token must be used for real purposes.
        await Task.delay(delay, token);
      } catch (e) {
        _message('Gen error: $e');
        rethrow;
      }

      _message('Work complete: $i');
      yield i;
      _message('After sent: $i');
    }
  }

  for (final basicFunctionality in [true, false]) {
    _header('Basic functionality: $basicFunctionality');

    // Not used for `timeout` demonstration purpose.
    // Manual cancellation will not be applied.
    final cts = CancellationTokenSource();

    var stream = gen(cts.token);
    if (!basicFunctionality) {
      stream = CancelableStreamFactory.fromGenerator(gen);
    }

    stream = stream.asCancelable(
      cts.token,
      blockOnCancel: false,
      timeout: Duration(milliseconds: timeout),
    );

    _watch.reset();
    _watch.start();
    try {
      await for (final event in stream) {
        _message('Enter await $event');
        // Performing the work longer than the timeout
        await Future<void>.delayed(const Duration(milliseconds: timeout * 2));
        _message('Exit await $event');
      }
    } catch (e) {
      _message('Error: $e');
    }

    _message('Begin new work');

    /// Waiting for example to terminate
    await Task.delay(3000);
  }
}

final _watch = Stopwatch();

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
