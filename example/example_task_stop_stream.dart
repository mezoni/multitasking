import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final controller = StreamController<int>();
  final master = await Task.run<void>(name: 'master', () async {
    Task.onExit((task) {
      print('Exit $task');
      if (!controller.isClosed) {
        print('$task closing controller');
        controller.close();
      }
    });

    var i = 0;
    Timer.periodic(Duration(seconds: 1), (timer) {
      controller.add(i++);
    });

    // Wait  forever
    await Completer<void>().future;
  });

  final stream = controller.stream;
  final slave = await Task.run<void>(name: 'slave', () async {
    Task.onExit((task) {
      print('Exit $task');
    });

    await for (final value in stream) {
      print(value);
      await Task.sleep();
    }
  });

  Timer(Duration(seconds: 3), () {
    print('Stop $slave');
    slave.stop();
    print('Stop $master');
    master.stop();
  });

  try {
    await Task.waitAll([master, slave]);
  } catch (e) {
    print(e);
  }

  print('Tasks stopped');
}
