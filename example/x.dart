import 'dart:ffi';

import 'package:multitasking/multitasking.dart';

void main(List<String> args) {
  final cts = CancellationTokenSource();
  final t = cts.token;

  final list1 = <WeakReference<void Function()>>[];
  final list2 = <void Function()>[];

  final sw = Stopwatch()..start();
  final t1 = sw.elapsedMicroseconds;
  for (var i = 0; i < 1000000; i++) {
    list1.add(WeakReference(() {
      //
    }));
  }

  final t2 = sw.elapsedMicroseconds;
  print((t2 - t1) / 1000000);

  final t3 = sw.elapsedMicroseconds;
  for (var i = 0; i < 1000000; i++) {
    list2.add(() {
      //
    });
  }

  final t4 = sw.elapsedMicroseconds;
  print((t4 - t3) / 1000000);

  final t5 = sw.elapsedMicroseconds;
  for (var i = 0; i < 1000000; i++) {
    final handler = t.addHandler(() {
      //
    });

    t.removerHandler(handler);
  }

  final t6 = sw.elapsedMicroseconds;
  print((t6 - t5) / 1000000);
}
