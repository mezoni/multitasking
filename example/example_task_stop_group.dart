import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final group = <Task<int>>[];
  final parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((me) {
      print('On exit: $me (${me.state.name})');
      if (me.state != TaskState.completed) {
        for (var i = 0; i < group.length; i++) {
          final task = group[i];
          if (!task.isTerminated) {
            print('${me.name} stops \'${task.name}\' (${task.state.name})');
            task.stop();
          }
        }
      }
    });

    for (var i = 0; i < 3; i++) {
      final t = Task.run<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: $task (${task.state.name})');
        });

        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;
          await Future<void>.delayed(Duration(seconds: 2));
        }

        return result;
      });

      group.add(t);
    }

    await Task.waitAll(group);
  });

  Timer(Duration(seconds: 2), () {
    print('Stopping $parent');
    parent.stop();
  });

  try {
    await parent;
  } catch (e) {
    //
  }
}
