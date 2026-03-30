import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(() {
    _message('Started');
    Object? handle;

    Task.onExit((task) {
      _message("Exit with status '${task.state.name}'");
      if (handle != null) {
        _message("Frees up 'handle'");
      }
    });

    handle = Object();
    throw Exception('Error in ${Task.current}');
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

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
