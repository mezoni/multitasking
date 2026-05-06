import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';

Future<void> main(List<String> args) async {
  _header('Terminate immediately');
  final runner1 = IsolateRunner(_computeSync);
  Timer(Duration(milliseconds: 100), () => runner1.terminate(immediate: true));
  try {
    await runner1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate via the event queue');
  final runner2 = IsolateRunner(_computeAsync);
  Timer(Duration(milliseconds: 100), runner2.terminate);
  try {
    await runner2.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final runner3 = IsolateRunner(_computeWithToken, token: cts.token);
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await runner3.run();
  } catch (e) {
    print('Error: $e');
  }
}

Future<int> _computeAsync() async {
  _message('Start');
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
  }
}

void _computeSync() {
  _message('Start');
  while (true) {}
}

Future<int> _computeWithToken() async {
  _message('Start');
  final token = Task.token;
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
    token.throwIfCanceled();
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
}

void _message(Object object) {
  print('Isolate(${Isolate.current.hashCode}): $object');
}
