import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork1(1, 200),
    doSomeWorkWithError(300),
    doSomeWork1(2, 400),
  ];

  print('whenAny');
  final firstTask = await whenAny(tasks);
  print('$firstTask: ${firstTask.state.name}');
  print('Tasks');
  print(tasks.map((e) {
    return '$e: ${e.state.name}';
  }).join(', '));

  print('whenAll');
  await whenAll(tasks);

  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    var s = '$task: ${task.state.name}';
    if (task.isCompleted) {
      s += ', result: ${task.result}';
    } else {
      s += ', exception: ${task.exception!.error}';
    }

    print(s);
  }
}

Task<int> doSomeWork1(int n, int ms) {
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

Future<void> whenAll<T>(List<Task<T>> tasks) async {
  final completer = Completer<void>();
  var count = 0;
  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    unawaited(() async {
      try {
        await task;
      } catch (e) {
        //
      } finally {
        if (++count == tasks.length) {
          completer.complete();
        }
      }
    }());
  }

  return completer.future;
}

Future<Task<T>> whenAny<T>(List<Task<T>> tasks) async {
  final completer = Completer<Task<T>>();
  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    unawaited(() async {
      try {
        await task;
      } catch (e) {
        //
      } finally {
        if (!completer.isCompleted) {
          completer.complete(task);
        }
      }
    }());
  }

  return completer.future;
}
