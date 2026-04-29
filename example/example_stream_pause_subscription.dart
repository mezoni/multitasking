import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  Stream<int> gen() async* {
    for (var i = 0; i < 10; i++) {
      _message('Yield: $i');
      yield i;
      await Task.delay(100);
    }

    _message('Generation complete');
  }

  final pts = PauseTokenSource();
  final cts = CancellationTokenSource();
  _watch.start();
  Timer(Duration(milliseconds: 50), () async {
    _message('Pause');
    await pts.pause();
  });

  Timer(Duration(milliseconds: 500), () async {
    _message('Resume');
    await pts.resume();
  });

  Timer(Duration(milliseconds: 650), () async {
    _message('Cancel');
    cts.cancel();
  });

  final stream = gen().asPausable(pts.token).asCancelable(cts.token);
  try {
    await for (final event in stream) {
      _message('Event: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }
}

final _watch = Stopwatch();

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
