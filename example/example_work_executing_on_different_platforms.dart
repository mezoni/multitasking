import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/work.dart';

Future<void> main(List<String> args) async {
  _header('Terminate (force = false)');
  final work1 = Work.create(_computeAsync);
  print('work1 is ${work1.runtimeType}');
  Timer(Duration(milliseconds: 100), work1.terminate);
  try {
    await work1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final work2 = Work.create(_computeWithToken, token: cts.token);
  print('work2 is ${work2.runtimeType}');
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await work2.run();
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
  print('Zone(${Zone.current.hashCode}): $object');
}
