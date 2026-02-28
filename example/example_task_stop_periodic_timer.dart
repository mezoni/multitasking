import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(name: 'task with timer', () async {
    Timer.periodic(Duration(milliseconds: 500), (_) {
      print('tick');
    });

    await Task.sleep(1500);
  });

  await task;
  print('$task ${task.state.name}');
  await Task.sleep(1500);
  print('Let\'s wait and see what happens.');
}
