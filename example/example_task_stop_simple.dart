import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  const duration = Duration(seconds: 5);
  final task = Task(name: 'my task', () async {
    Task.onExit((task) {
      print('On exit: $task, state: \'${task.state.name}\'');
    });

    print('running...');
    await Future<void>.delayed(duration);
    print('done');
  });

  await task.start();
  print('Stop $task with state \'${task.state.name}\'');
  task.stop();
  try {
    await task;
  } catch (e, s) {
    print('Big bada boom?');
    print('$e\n$s');
    print('Oh no, it was just a faint hiss...');
  }

  print('Waiting ${duration.inSeconds} sec. to see what happens...');
  await Future<void>.delayed(duration);
  print('Continue to work');
}
