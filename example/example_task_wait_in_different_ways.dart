import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork(1, 200),
    doSomeWork(1, 300),
  ];

  final progress = Progress((int percent) {
    print('Waiting: $percent%');
  });

  print('whenAny()');
  final firstTask = await whenAny(tasks, progress: progress);
  print('${firstTask.toString()}: ${firstTask.state.name}');
  print('Tasks');
  print(tasks.map((e) {
    return '$e: ${e.state.name}';
  }).join(', '));

  print('whenAll()');
  await whenAll(tasks, progress: progress);

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

Future<void> whenAll<T>(
  List<Task<T>> tasks, {
  Progress<int>? progress,
}) async {
  if (tasks.isEmpty) {
    progress?.report(100);
    return Future.value();
  }

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
        ++count;
        final percent = count * 100 ~/ tasks.length;
        progress?.report(percent);
        if (count == tasks.length) {
          completer.complete();
        }
      }
    }());
  }

  return completer.future;
}

Future<Task<T>> whenAny<T>(
  List<Task<T>> tasks, {
  Progress<int>? progress,
}) async {
  if (tasks.isEmpty) {
    throw ArgumentError('Task list must not be empty', 'tasks');
  }

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
          final percent = 1 * 100 ~/ tasks.length;
          progress?.report(percent);
          completer.complete(task);
        }
      }
    }());
  }

  return completer.future;
}

class Progress<T> {
  final FutureOr<void> Function(T) _callback;

  final Zone _zone;

  Progress(final FutureOr<void> Function(T) callback)
      : _callback = callback,
        _zone = Zone.current;

  void report(T event) {
    _zone.scheduleMicrotask(() {
      _callback(event);
    });
  }
}
