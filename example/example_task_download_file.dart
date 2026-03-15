import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:multitasking/misc/progress.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  final progress = Progress((int byteCount) {
    stdout.write('\r\x1B[2KDownloaded: $byteCount bytes');
  });

  final url = Uri.parse(
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.10.9/sdk/dartsdk-windows-x64-release.zip');
  const filename = 'dart_sdk';
  final task = _download(url, filename, token, progress: progress);

  // User request to cancel
  Timer(Duration(seconds: 5), () {
    print('');
    print('Cancelling...');
    cts.cancel();
  });

  try {
    await task;
  } catch (e) {
    print('$e');
  }

  if (task.isCompleted) {
    final filename = await task;
    print('Done: $filename');
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token,
    {Progress<int>? progress}) {
  return Task.run(() async {
    _message('Starting download');
    final bytes = <int>[];

    Task.onExit((task) {
      print('$task: ${task.state.name}');
      _message('Downloaded: ${bytes.length}');
    });

    token.throwIfCancelled();
    final client = Client();
    final abortTrigger = Completer<void>();

    Future<void> get() async {
      final request =
          AbortableRequest('GET', uri, abortTrigger: abortTrigger.future);
      final StreamedResponse response;
      try {
        response = await client.send(request);
      } on RequestAbortedException {
        throw TaskCanceledError();
      }

      try {
        await response.stream.listen((data) {
          bytes.addAll(data);
          progress?.report(bytes.length);
        }).asFuture<void>();
      } on RequestAbortedException {
        throw TaskCanceledError();
      }
    }

    await runCancellable(token, abortTrigger.complete, get);

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
