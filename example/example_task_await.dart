import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = await Task.run<int>(() => throw 'Error');

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
