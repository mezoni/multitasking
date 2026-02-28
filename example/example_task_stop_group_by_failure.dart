import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  late AnyTask parent;
  final group = <Task<int>>[];

  void onExit(AnyTask task) {
    void stop(AnyTask task) {
      if (!task.isTerminated) {
        task.stop();
      }
    }

    if (task.state != TaskState.completed) {
      for (final task in group) {
        stop(task);
      }
    }

    stop(parent);
  }

  parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: $task (${task.state.name})');
      onExit(task);
    });

    for (var i = 0; i < 3; i++) {
      final t = Task<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: $task (${task.state.name})');
          onExit(task);
        });

        final n = i;
        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;
          await Future<void>.delayed(Duration(seconds: 2));
          if (n == 1) {
            throw 'Failure in ${Task.current}';
          }
        }

        print('${Task.current} work done');
        return result;
      });

      group.add(t);
    }

    for (final task in group) {
      task.start();
      await Task.sleep();
    }

    await Task.waitAll(group);
  });

  try {
    await parent;
  } catch (e) {
    //
  }
}
