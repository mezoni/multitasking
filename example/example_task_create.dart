import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = <Task<int>>[];
  for (var i = 0; i < 4; i++) {
    print('Creating task');
    tasks.add(Task.run(name: '', () async {
      Task.onExit((task) {
        print('On exit: $task');
        if (task.state == TaskState.completed) {
          print('$task ${task.state.name}');
        }
      });

      final result = i;
      await Task.sleep();
      if (i == 2) {
        throw 'Error in ${Task.current}';
      }

      return result;
    }));

    await Task.sleep();
  }

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }
}
