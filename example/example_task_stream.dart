import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork(1, 200),
    doSomeWork(2, 300),
  ];

  await for (final task in Task.whenEach(tasks)) {
    print('${task.toString()} ${task.status.name}');
    if (task.isSuccessful) {
      final result = await task;
      print('${task.toString()} result $result');
    }
  }
}

Task<int> doSomeWork(int n, int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return n;
  });
}

Task<int> doSomeWorkWithError(int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    throw StateError('Some error');
  });
}
