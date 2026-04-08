import 'dart:async';

import 'package:multitasking/multitasking.dart';

void main(List<String> args) async {
  var state1 = 'running';
  var state2 = 'running';
  var state3 = 'running';
  final stream1 = Stream.periodic(Duration(seconds: 1), (count) {
    return count;
  }).withCancellationHandler(() {
    state1 = 'canceled';
  });

  final sub1 = stream1.listen(print);

  final stream2 = Stream.periodic(Duration(seconds: 1), (count) {
    return count;
  }).withCancellationHandler(() {
    state2 = 'canceled';
  });

  unawaited(() async {
    await for (final event in stream2) {
      print(event);
      if (event > 2) {
        break;
      }
    }
  }());

  final stream3 = Stream.periodic(Duration(seconds: 1), (count) {
    return count;
  });

  final sub3 = stream3.listenWithCancellationHandler(print, onCancel: () {
    state3 = 'canceled';
  });

  await Future<void>.delayed(Duration(seconds: 4));
  await sub1.cancel();
  await sub3.cancel();
  print(state1);
  print(state2);
  print(state3);
}
