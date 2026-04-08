import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/reset_events.dart';

Future<void> main() async {
  final mre = ManualResetEvent(false);
  final watch = Stopwatch();
  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final task = Task.run(() async {
      await mre.wait();
      _message('${watch.elapsedMilliseconds}');
    });

    tasks.add(task);
  }

  const ms = 500;
  watch.start();
  _message('${watch.elapsedMilliseconds}');
  _message('Waiting $ms ms');
  await Future<void>.delayed(Duration(milliseconds: ms));
  _message('Start');
  await mre.set();
  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
