import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';

void main(List<String> args) async {
  var cts = CancellationTokenSource();
  await bigWork(cts);

  cts = CancellationTokenSource();
  Timer(Duration(seconds: 2), () {
    _message('Cancelling...');
    cts.cancel();
  });

  await bigWork(cts);
}

Future<void> bigWork(CancellationTokenSource cts) async {
  _message('-' * 40);
  final token = cts.token;

  final tasks = <AnyTask>[];
  for (var i = 0; i < 5; i++) {
    final task = Task.run(() async {
      final result = await _computeUsingIsolate(doWork, token);
      _message('Received result: $result');
    });

    _message('Adding task $i');
    tasks.add(task);
    // Allow task to start
    await Task.sleep();
  }

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }
}

void doWork(SendPort sendPort) async {
  final port = ReceivePort();
  try {
    final cts = _createCancellationTokenSource(port, sendPort);
    final token = cts.token;
    print("Isolate started: ${Isolate.current.hashCode}");
    var result = 0;

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration(milliseconds: 250));
      token.throwIfCancelled();
      result++;
      //throw 'Error';
    }

    //throw 'Error';
    sendPort.send(result);
  } finally {
    port.close();
  }
}

Future<Object?> _computeUsingIsolate(
  void Function(SendPort) computation,
  CancellationToken token,
) async {
  final port = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final barrier = Completer<SendPort>();
  final result = <Object?>[];
  final resultCompleter = Completer<Object?>();
  void Function()? handler;

  final isolate = await Isolate.spawn(
    computation,
    port.sendPort,
    paused: true,
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  void closeAll() {
    if (!resultCompleter.isCompleted) {
      resultCompleter.complete(result);
    }

    token.removerHandler(handler);
    port.close();
    errorPort.close();
    exitPort.close();
  }

  errorPort.listen((message) {
    if (!resultCompleter.isCompleted) {
      final exception = message as List<Object?>;
      final error = exception[0] as Object;
      final stackTraceString = exception[1];
      StackTrace? stackTrace;
      if (stackTraceString is String) {
        stackTrace = StackTrace.fromString(stackTraceString);
      }

      resultCompleter.completeError(error, stackTrace);
    }
  });

  exitPort.listen((message) {
    closeAll();
  });

  isolate.resume(isolate.pauseCapability!);
  port.listen((message) {
    if (message is SendPort) {
      barrier.complete(message);
    } else {
      result.add(message);
    }
  });

  final cancelPort = await barrier.future;
  handler = token.addHandler(() {
    cancelPort.send(null);
  });

  return resultCompleter.future;
}

CancellationTokenSource _createCancellationTokenSource(
  ReceivePort port,
  SendPort sendPort,
) {
  final cts = CancellationTokenSource();
  sendPort.send(port.sendPort);
  port.listen((message) {
    cts.cancel();
  });

  return cts;
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
