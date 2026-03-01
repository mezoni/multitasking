import 'dart:async';
import 'dart:io';

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
  Timer(Duration(seconds: 2), cts.cancel);

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    if (task.state == TaskState.completed) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    final client = HttpClient();
    final bytes = <int>[];

    token.throwIfCancelled();
    token.addHandler(Task.current, (task) {
      // If [force] is `true` any active/ connections will be closed to
      // immediately release all resources.
      client.close(force: true);
    });

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        await for (final event in response) {
          if (token.isCancelled) {
            client.close(force: true);
            break;
          }

          bytes.addAll(event);
        }
      } else {
        throw 'HTTP error: ${response.statusCode}';
      }
    } finally {
      print('Close client');
      token.removeHandler(Task.current);
      client.close();
    }

    token.throwIfCancelled();

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}
