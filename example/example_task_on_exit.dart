import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(() {
    Object? handle;

    Task.onExit((task) {
      print("${task.toString()} exit with status: '${task.state.name}'");
      if (handle != null) {
        print("${task.toString()} frees up: 'handle'");
      }
    });

    handle = Object();
    throw Exception('Error');
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
