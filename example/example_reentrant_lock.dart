import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/reentrant_lock.dart';

Future<void> main(List<String> args) async {
  final lock = ReentrantLock();
  var count = 0;

  Future<void> func(int i) async {
    await lock.acquire();
    try {
      await Future<void>.delayed(Duration(milliseconds: 50));
      count++;
      _message('Increment counter: $count');
      if (i + 1 < 3) {
        await func(i + 1);
      }
    } finally {
      await lock.release();
    }
  }

  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final t = Task.run(() => func(0));
    tasks.add(t);
  }

  await Task.waitAll(tasks);
}

void _message(String text) {
  print('${Task.current}: $text');
}
