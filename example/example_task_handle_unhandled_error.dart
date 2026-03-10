import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = runZonedGuarded(() async {
    final task = Task.run(() {
      Timer(Duration(seconds: 1), () {
        throw 'Error 2';
      });
      throw 'Error 1';
    });

    try {
      await task;
    } catch (e) {
      print('Task error: $e');
    }
  }, (error, stack) {
    print('Unhandled error: $error');
  });

  try {
    await task;
  } catch (e) {
    print('Task error: $e');
  }
}
