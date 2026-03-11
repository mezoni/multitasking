import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(() {
    return 42;
  });

  await task;
  print(task.result);
}
