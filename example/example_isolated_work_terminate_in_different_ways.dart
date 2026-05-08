import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/isolated_work.dart';

Future<void> main(List<String> args) async {
  _header('Terminate (force = true)');
  final work1 = IsolatedWork(_computeSync);
  Timer(Duration(milliseconds: 100), () => work1.terminate(force: true));
  try {
    await work1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate (force = false)');
  final work2 = IsolatedWork(_computeAsync);
  Timer(Duration(milliseconds: 100), work2.terminate);
  try {
    await work2.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final work3 = IsolatedWork(_computeWithToken, token: cts.token);
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await work3.run();
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
