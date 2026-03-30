import 'dart:async';
import 'dart:isolate';

import 'package:defer/defer.dart';
import 'package:multitasking/multitasking.dart';

void main(List<String> args) async {
  var cts = CancellationTokenSource();
  await bigWork(cts);

  cts = CancellationTokenSource();
  Timer(Duration(seconds: 2), () {
    _message('Canceling...');
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
      token.throwIfCanceled();
      final controller = StreamController<int>();
      final results = <int>[];
      controller.stream.listen(results.add);

      await defer(controller.close, () async {
        await _computeUsingIsolate(doWork, i, controller.sink, token);
      });

      _message('Received result: $results');
    });

    _message('Adding task $i');
    tasks.add(task);
    // Allow task to start
    await Task.sleep();
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

Future<void> doWork((SendPort, int) message) async {
  final (sendPort, arg) = message;
  final port = ReceivePort();
  try {
    final cts = _createCancellationTokenSource(port, sendPort);
    final token = cts.token;
    print("Isolate started: ${Isolate.current.hashCode}");
    var result = arg;

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration(milliseconds: 250));
      token.throwIfCanceled();
      result++;
      //throw 'Error';
    }

    //throw 'Error';
    sendPort.send(result);
  } finally {
    port.close();
  }
}

Future<void> _computeUsingIsolate<T, R>(
  void Function((SendPort, T)) computation,
  T argument,
  Sink<R> sink,
  CancellationToken token,
) async {
  final port = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final barrier = Completer<SendPort>();
  final resultCompleter = Completer<void>();
  void Function()? handler;

  final isolate = await Isolate.spawn(
    computation,
    (port.sendPort, argument),
    paused: true,
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  void closeAll() {
    if (!resultCompleter.isCompleted) {
      resultCompleter.complete();
    }

    token.removerHandler(handler);
    port.close();
    errorPort.close();
    exitPort.close();
  }

  errorPort.listen((message) {
    if (!resultCompleter.isCompleted) {
      final exception = message as List<Object?>;
      final error = exception[0]!;
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
      sink.add(message as R);
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
