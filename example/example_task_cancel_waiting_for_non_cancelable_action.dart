import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource(Duration(seconds: 1));
  final task = _longTask();
  try {
    final result = await task.withCancellation(cts.token);
    print('Result: $result');
  } on TaskCanceledException {
    print('TaskCanceledException');
    if (!task.isTerminated) {
      print('Task still running');
    }
  }

  print('Begin next work');
}

Task<int> _longTask() {
  return Task.run(() async {
    await Future<void>.delayed(Duration(seconds: 2));
    print('Task terminated');
    return 10;
  });
}
