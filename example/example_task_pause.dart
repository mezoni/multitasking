import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final pts = PauseTokenSource();
  final pause = pts.token;

  _watch.start();
  Timer(Duration(milliseconds: 50), () async {
    _message('pause');
    await pts.pause();
  });

  Timer(Duration(milliseconds: 500), () async {
    _message('resume');
    await pts.resume();
  });

  final list = await _doWork(pause);
  print(list);
}

final _watch = Stopwatch();

Task<List<int>> _doWork(PauseToken pause) {
  return Task.run(() async {
    final list = <int>[];
    for (var i = 0; i < 3; i++) {
      _message(i);
      list.add(i);
      // Simulate some work
      await Task.delay(100);
      await pause.wait();
    }

    return list;
  });
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}
