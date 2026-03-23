import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = <Task<int>>[];
  for (var i = 0; i < 4; i++) {
    print('Creating task');
    tasks.add(Task.run(name: '', () async {
      Task.onExit((task) {
        _message('On exit: ${task.state.name}');
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
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
