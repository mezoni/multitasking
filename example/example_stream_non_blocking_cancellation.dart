import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  for (final blockOnCancel in [true, false]) {
    print('-' * 40);
    print('${blockOnCancel ? 'Blocking' : 'Non-blocking'} cancellation ');
    print('-' * 40);
    _watch.reset();
    _watch.start();
    final cts = CancellationTokenSource();
    Timer(Duration(milliseconds: 200), () {
      _message('Canceling');
      cts.cancel();
    });

    final stream =
        _generate().asCancelable(cts.token, blockOnCancel: blockOnCancel);
    try {
      await for (final event in stream) {
        _message('Received: $event');
      }
    } catch (e) {
      _message('catch(e): $e');
    }

    _message('Begin next work');
    await Future<void>.delayed(Duration(milliseconds: 50));
    _message('End next work');
  }
}

final _watch = Stopwatch();

Future<int> _compute(int value) async {
  _message('Computing');
  await Task.delay(150);
  if (value == 1) {
    _message('Error computing');
    throw Exception('Error');
  } else {
    _message('Computed: $value');
  }

  return value;
}

Stream<int> _generate() async* {
  for (var i = 0; i < 10; i++) {
    yield await _compute(i);
    _message('After yield: $i');
  }

  _message('Generation complete');
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
