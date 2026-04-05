import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task(name: 'my task', () async {
    print('-' * 40);
    print('Task started');
    Timer(Duration(milliseconds: 400), () {});
    await Future<void>.delayed(const Duration());
    return 42;
  });

  final zoneStats = task.zoneStats;
  if (zoneStats != null) {
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      print('-' * 40);
      if (zoneStats.isZoneActive || task.isCreated) {
        print('Active microtasks: ${zoneStats.activeMicrotasks}');
        print('Active periodic timers: ${zoneStats.activePeriodicTimers}');
        print('Active timers: ${zoneStats.activeTimers}');
      } else {
        timer.cancel();
        print('Scheduled microtasks: ${zoneStats.scheduledMicrotasks}');
        print('Created periodic timers: ${zoneStats.createdPeriodicTimers}');
        print('Created timers: ${zoneStats.createdTimers}');
      }
    });
  }

  await Future<void>.delayed(Duration(milliseconds: 100));
  await task.start();
  await task;
}
