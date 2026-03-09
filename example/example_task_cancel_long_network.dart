import 'dart:async';

import 'package:defer/defer.dart';
import 'package:http/http.dart' as http;
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/stream/cancellable_stream_iterator.dart';

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
    print('Cancelling...');
    cts.cancel();
  });

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print('$e');
  }

  for (final task in tasks) {
    if (task.isCompleted) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    final bytes = <int>[];
    token.throwIfCancelled();
    final client = http.Client();
    await defer(() async {
      print('Close client');
      client.close();
      _message('Downloaded: ${bytes.length}');
    }, () async {
      final request = http.Request('GET', uri);
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw StateError('Http error (${response.statusCode}): $uri');
      }

      final iterator = CancellableStreamIterator(response.stream, token);
      await defer(iterator.cancel, () async {
        while (await iterator.moveNext()) {
          bytes.addAll(iterator.current);
        }
      });
    });

    token.throwIfCancelled();
    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
