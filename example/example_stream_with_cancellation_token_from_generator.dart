import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  Stream<int> streamFromGenerator(CancellationToken token) async* {
    _message('Before yield: 1');
    yield 1;
    _message('After yield: 1');
    // await Task.delay(4000, token);
    await _doWork(token);
    yield 2;
  }

  _header("Cancel with 'CancellationTokenSource'");
  final cts = CancellationTokenSource();
  Timer(Duration(seconds: 2), cts.cancel);
  final stream1 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.start();
  try {
    await for (final event in stream1.asCancelable(cts.token)) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _header("Cancel with 'StreamSubscription.cancel()'");
  final stream2 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.reset();
  _watch.start();
  final subscription = stream2.listen(
    (event) {
      _message('Received: $event');
    },
    onError: (Object e) {
      _message('Error: $e');
    },
  );

  Timer(Duration(seconds: 2), () async {
    try {
      await subscription.cancel();
    } catch (e) {
      _message('Error: $e');
    }
  });
}

final _watch = Stopwatch();

Future<void> _doWork(CancellationToken token) async {
  const x = 10;
  const y = 10;
  const z = 40;
  const executionTime = x * y * z;
  _message('Begin work (about $executionTime ms)');
  try {
    for (var i = 0; i < x; i++) {
      for (var j = 0; j < y; j++) {
        token.throwIfCanceled();
        await Future<void>.delayed(Duration(milliseconds: z));
      }
    }
  } on CancellationException {
    _message('Work canceled');
    rethrow;
  }

  _message('End work');
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
