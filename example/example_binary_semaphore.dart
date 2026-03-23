import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';

Future<void> main(List<String> args) async {
  final sem = BinarySemaphore();
  final tasks = <AnyTask>[];

  for (var i = 0; i < 5; i++) {
    final task = Task.run(name: 'task $i', () async {
      await Task.sleep();
      _message('acquire');
      await sem.acquire();
      try {
        _message('  acquired');
        await Task.sleep();
      } finally {
        _message('release');
        await sem.release();
      }
    });

    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
