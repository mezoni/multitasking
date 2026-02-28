import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = await Task.run<int>(() {
    Object? handle;

    Task.onExit((task) {
      print('$task exit with status: \'${task.state.name}\'');
      if (handle != null) {
        print('$task frees up: \'handle\'');
      }
    });

    handle = Object();
    throw 'Error';
  });

  print('Do some work');
  await Future<void>.delayed(Duration(seconds: 1));
  print('Work completed');

  try {
    final result = await task;
    print('Result: $result');
  } catch (e) {
    print(e);
  }
}
