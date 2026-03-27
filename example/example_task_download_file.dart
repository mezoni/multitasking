import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:multitasking/misc/progress.dart';
import 'package:multitasking/misc/speed_meter.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  final meter = SpeedMeter();
  var percent = 0;
  final progress = Progress((({int byteCount, int percent}) data) {
    percent = data.percent;
    return null;
  });

  final timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    if (token.isCanceled) {
      timer.cancel();
    }

    final speed = (meter.speed / (1024 * 1024)).toStringAsFixed(2);
    final size = (meter.totalAmount / (1024 * 1024)).toStringAsFixed(2);
    stdout.write('\r\x1B[2KDownloaded: $size MB ($percent%, $speed Mbps)');
  });

  final url = Uri.parse(
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.10.9/sdk/dartsdk-windows-x64-release.zip');
  const filename = 'dart_sdk';
  meter.resume();
  final task =
      _download(url, filename, token, progress: progress, meter: meter);

  const sec = 10;
  // User request to cancel
  Timer(Duration(seconds: sec), () {
    print('');
    print('Canceling after $sec sec');
    cts.cancel();
  });

  try {
    await task;
  } catch (e) {
    print('$e');
  }

  timer.cancel();
  if (task.isCompleted) {
    final filename = await task;
    print('Done: $filename');
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token,
    {Progress<({int byteCount, int percent})>? progress, SpeedMeter? meter}) {
  return Task.run(() async {
    _message('Starting download');
    final bytes = <int>[];

    Task.onExit((task) {
      print('${task.toString()}: ${task.state.name}');
      _message('Downloaded: ${bytes.length} bytes');
    });

    token.throwIfCanceled();
    final client = Client();
    final abortTrigger = Completer<void>();

    Future<void> get() async {
      final request =
          AbortableRequest('GET', uri, abortTrigger: abortTrigger.future);
      final StreamedResponse response;
      try {
        response = await client.send(request);
      } on RequestAbortedException {
        throw TaskCanceledException();
      }

      final contentLength = response.contentLength;
      try {
        await response.stream.listen((data) {
          final byteCount = bytes.length;
          meter?.add(data.length);
          bytes.addAll(data);
          final percent = contentLength != null && contentLength != 0
              ? byteCount * 100 ~/ contentLength
              : 0;
          progress?.report((
            byteCount: byteCount,
            percent: percent,
          ));
        }).asFuture<void>();
      } on RequestAbortedException {
        throw TaskCanceledException();
      }
    }

    await token.runCancelable(abortTrigger.complete, get);

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
