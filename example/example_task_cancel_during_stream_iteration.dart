import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final controller = StreamController<int>.broadcast();

  final stream = controller.stream;
  final cts = CancellationTokenSource();
  final token = cts.token;

  var n = 0;
  Timer.periodic(Duration(seconds: 1), (timer) {
    print('Send event: $n');
    controller.add(n++);
    if (n > 5) {
      print('Stopping the controller');
      timer.cancel();
      unawaited(controller.close());
    }
  });

  Timer(Duration(seconds: 3), () {
    _message('Cancellation requested');
    cts.cancel();
  });

  final tasks = <Task<int>>[];
  for (var i = 0; i < 3; i++) {
    final task = _doWork(stream, token, testBreak: i == 2);
    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    if (task.isCompleted) {
      final result = await task;
      _message('Result of ${task.toString()}: $result');
    }
  }
}

Task<int> _doWork(
  Stream<int> stream,
  CancellationToken token, {
  bool testBreak = false,
}) {
  return Task.run(() async {
    token.throwIfCanceled();
    final list = <int>[];
    final cts = CancellationTokenSource.createLinkedTokenSource([token]);
    await stream.listenWithCancellation(
      token: cts.token,
      throwIfCancelled: !testBreak,
      (data) {
        _message('Received event: $data');
        list.add(data);
        if (testBreak && list.length == 1) {
          _message('I want to break free...');
          // Breaks silently, without throwing a `TaskCanceledException`
          // exception (throwIfCancelled: false).
          cts.cancel();
        }
      },
    ).asFuture<void>();

    await Task.sleep();
    _message('Processing data: $list');
    if (testBreak) {
      return list.length;
    }

    await Future<void>.delayed(Duration(seconds: 1));
    return list.length;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
