import 'dart:async';

import 'package:multitasking/misc/progress.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork(1, 200),
    doSomeWork(2, 300),
  ];

  final progress = Progress((({int count, int total}) info) {
    final (:count, :total) = info;
    final percent = (total == 0 ? 100 : 100 * count / total).toStringAsFixed(2);
    print('Ready: $percent%');
  });

  print('whenAny()');
  final firstTask = await Task.whenAny(tasks, progress: progress);
  print('First task: ${firstTask.toString()} (${firstTask.state.name})');
  try {
    final result = await firstTask;
    print('First result: $result');
  } catch (e) {
    print('Error: $e');
  }

  print('Tasks:');
  print(tasks.map((e) {
    return '${e.toString()} (${e.state.name})';
  }).join(', '));

  print('whenAll()');
  try {
    final results = await Task.whenAll(tasks);
    print('Results: $results');
  } catch (e) {
    print('Error: $e');
  }

  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    var s = '${task.toString()}: ${task.state.name}';
    if (task.isCompleted) {
      s += ', result: ${task.result}';
    } else {
      s += ', exception: ${task.exception!.error}';
    }

    print(s);
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
