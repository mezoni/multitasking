import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main(List<String> args) async {
  final cts = CancellationTokenSource();
  final token = cts.token;

  var count = 0;
  final task = Task.run(() async {
    while (true) {
      count++;
      await Task.sleep(0, token);
    }
  });

  Timer(Duration(seconds: 1), cts.cancel);

  try {
    await task;
  } catch (e) {
    print(e);
  }

  _message('count: $count');
}

void _message(String text) {
  print('${Task.current}: $text');
}
