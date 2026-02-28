import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(name: 'task with timer', () async {
    scheduleMicrotask();
    await Task.sleep(1500);
  });

  await task;
  print('$task ${task.state.name}');
  await Task.sleep(1500);
  print('Let\'s wait and see what happens.');
}

void createTimer() {
  Timer(Duration(milliseconds: 500), () {
    print('tick');
    scheduleMicrotask();
  });
}

void scheduleMicrotask() {
  Zone.current.scheduleMicrotask(createTimer);
}
