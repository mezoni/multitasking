import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(name: 'my task', () {
    return 1;
  });

  print(task.name);
  await task;
}
