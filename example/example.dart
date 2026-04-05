import 'dart:async';

import 'package:http/http.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  final list = [
    (
      '3.11.1',
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.1/sdk/dartsdk-windows-x64-release.zip'
    ),
    (
      '3.10.9',
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.10.9/sdk/dartsdk-windows-x64-release.zip'
    )
  ];

  final tasks = <AnyTask>[];
  for (final element in list) {
    final url = Uri.parse(element.$2);
    final filename = element.$1;
    final task = _download(url, filename, token);
    tasks.add(task);
  }

  // User request to cancel
  Timer(Duration(seconds: 2), () {
    print('Canceling...');
    cts.cancel();
  });

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print('$e');
  }

  for (final task in tasks) {
    if (task.isSuccessful) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    var bytes = 0;

    Task.onExit((task) {
      print('${task.toString()}: ${task.status.name}');
      _message('Downloaded: $bytes');
    });

    token.throwIfCanceled();
    final request = Request('GET', uri);
    final task = Task.run(() => Client().send(request));
    StreamedResponse response;
    try {
      response = await task.withCancellation(token);
    } on TaskCanceledException {
      // Ignore the cancelled connection establishment.
      unawaited(() async {
        try {
          await (await task).stream.listen((_) {}).cancel();
        } catch (e) {/**/}
      }());

      rethrow;
    }

    final stream = response.stream;
    await for (final event
        in stream.asCancelable(token, throwIfCanceled: true)) {
      // Simulating the addition of bytes
      bytes += event.length;
    }

    final statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception('Http error ($statusCode)');
    }

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
