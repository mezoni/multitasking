import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/multiple_write_single_read_object.dart';

Future<void> main(List<String> args) async {
  final object = MultipleWriteSingleReadObject(0);
  final tasks = <AnyTask>[];

  void scheduleTask(int ms, Future<void> Function() action) {
    final t = Task.run<void>(() async {
      await Task.sleep(ms);
      await action();
    });
    tasks.add(t);
  }

  void scheduleRead(int ms) {
    scheduleTask(ms, () async {
      var isLocked = false;
      if (object.isLocked) {
        isLocked = true;
        _message('wait read');
        await object.wait();
      }

      final v = object.read();
      final mode = isLocked ? 'read (after wait)' : 'read';
      _message('$mode $v');
    });
  }

  void scheduleWrite(int ms) {
    scheduleTask(ms, () async {
      _message('wait write');
      await object.write((value) async {
        await Future<void>.delayed(Duration(milliseconds: 100));
        final v = ++value;
        _message('write $v');
        return v;
      });
    });
  }

  scheduleRead(0);
  scheduleWrite(0);
  scheduleWrite(0);
  scheduleRead(0);
  scheduleRead(200);
  scheduleRead(400);

  await Task.waitAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
