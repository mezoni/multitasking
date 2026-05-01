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

  _header('Cancelling a cancellable stream');
  final cts1 = CancellationTokenSource();
  final stream1 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.start();
  try {
    await for (final event
        in stream1.asCancelable(cts1.token, timeout: Duration(seconds: 2))) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _message('End');

  _header('Cancelling a non-cancellable stream');
  final cts2 = CancellationTokenSource();
  final stream2 = streamFromGenerator(cts2.token);
  _watch.start();
  try {
    await for (final event in stream2.asCancelable(
      cts1.token,
      blockOnCancel: false,
      timeout: Duration(seconds: 2),
    )) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _message('End');
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
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

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
