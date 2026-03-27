import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';

Future<void> main() async {
  final sem = BinarySemaphore();
  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final task = Task.run(() async {
      await sem.lock(() async {
        _message('Enter');
        await Future<void>.delayed(Duration(milliseconds: 100));
        _message('Leave');
      });
    });

    tasks.add(task);
  }

  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
