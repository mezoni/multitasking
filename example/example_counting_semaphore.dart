import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/counting_semaphore.dart';

Future<void> main(List<String> args) async {
  final sem = CountingSemaphore(0, 3);
  final tasks = <AnyTask>[];
  _message('Round with asynchronous entry in the task body');
  for (var i = 0; i < 7; i++) {
    final task = Task.run(name: 'task $i', () async {
      // Asynchronous entry
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
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }

  tasks.clear();
  print('-' * 40);
  _message('Round with synchronous entry in the task body');
  for (var i = 0; i < 7; i++) {
    final task = Task.run(name: 'task $i', () async {
      // Synchronous entry
      // await Task.sleep();
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
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }
}

void _message(String text) {
  print('${Task.current.name}: $text');
}
