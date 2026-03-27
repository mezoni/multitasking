import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  // Text and time to complete a task
  final events = [
    ('A', 200),
    ('B', 100),
    ('C', 200),
    ('D', 100),
    ('E', 200),
    ('F', 100),
    ('G', 200),
    ('H', 100),
  ];

  final controller = StreamController<Task<String>>();
  unawaited(() async {
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final text = event.$1;
      final ms = event.$2;
      final Task<String> task;
      if (i == 2) {
        task = Task.run(() {
          throw Exception('Some error on $text');
        });
      } else {
        task = Task.run(() async {
          await Future<void>.delayed(Duration(milliseconds: ms));
          print('$text Ready');
          return text;
        });
      }

      controller.add(task);
      // Emulates a small interval between the receipt of tasks.
      await Future<void>.delayed(Duration(milliseconds: 75));
    }

    print('No more tasks');
    await controller.close();
  }());

  unawaited(() async {
    final stream = controller.stream;
    await for (final task in stream) {
      try {
        await task;
        print(task.result);
        // Do something with the result.
        await Future<void>.delayed(Duration(milliseconds: 200));
      } catch (e) {
        print(e);
      }
    }

    print("The end");
  }());

  print("Let's start");
}
