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
  final progress = Progress((({int count, int total}) data) {
    percent = data.total == 0 ? 0 : data.count * 100 ~/ data.total;
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
  if (task.isSuccessful) {
    final filename = await task;
    print('Done: $filename');
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token,
    {Progress<({int count, int total})>? progress, SpeedMeter? meter}) {
  return Task.run(() async {
    var bytes = 0;

    Task.onExit((task) {
      print('${task.toString()}: ${task.status.name}');
      _message('Downloaded: $bytes bytes');
    });

    token.throwIfCanceled();
    _message('Starting download');
    _message('Fetching feed: $uri');
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

    final contentLength = response.contentLength;
    final stream = response.stream;
    await for (final event
        in stream.asCancelable(token, throwIfCanceled: true)) {
      final byteCount = bytes;
      meter?.add(event.length);
      bytes += event.length;
      progress?.report((count: byteCount, total: contentLength ?? 0));
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
