import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    final task = Task.run(() {
      Task.onExit((task) {
        throw 'Error on exit';
      });

      Timer(const Duration(), () {
        throw 'Error in timer';
      });
      throw 'Error in body';
    });

    try {
      await task;
    } catch (e) {
      print('Task error: $e');
    }
  }, (error, stack) {
    print('Unhandled error: $error');
  });
}
