import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  late AnyTask parent;
  final group = <Task<int>>[];

  void onExit(AnyTask task) {
    if (!task.isCompleted) {
      cts.cancel();
    }
  }

  parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: ${task.toString()} (${task.state.name})');
      onExit(task);
    });

    token.throwIfCanceled();
    for (var i = 1; i <= 3; i++) {
      final t = Task<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: ${task.toString()} (${task.state.name})');
          onExit(task);
        });

        token.throwIfCanceled();
        final n = i;
        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;
          await Task.delay(500, token);
          if (n == 1) {
            throw Exception('Failure in ${Task.current}');
          }
        }

        print('${Task.current} work done');
        return result;
      });

      group.add(t);
    }

    for (final task in group) {
      await task.start();
      await Task.sleep();
    }

    await Task.whenAll(group);
  });

  try {
    await parent;
  } catch (e) {
    print(e);
  }
}
