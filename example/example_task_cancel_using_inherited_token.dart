import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts1 = CancellationTokenSource();
  Timer(Duration(milliseconds: 100), () {
    print('cts.cancel()');
    cts1.cancel();
  });

  final task = Task.run(token: cts1.token, () async {
    final tasks = <AnyTask>[];
    for (var i = 0; i < 5; i++) {
      final task = Task.run(_doWork);
      tasks.add(task);
    }

    await Task.whenAll(tasks);
  });

  try {
    await task;
  } catch (e) {
    _message('Error: $e');
  }
}

Future<void> _doWork() async {
  _message('Begin work');
  final token = Task.token;
  try {
    for (var i = 0; i < 10; i++) {
      token.throwIfCanceled();
      for (var j = 0; j < 10; j++) {
        await Future<void>.delayed(Duration(milliseconds: 10));
      }
    }
  } catch (e) {
    _message('Error: $e');
    rethrow;
  }

  _message('End work');
}

void _message(Object object) {
  print('${Task.current} $object');
}
