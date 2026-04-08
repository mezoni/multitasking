import 'dart:async';

import 'package:http/http.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  final tasks = <Task<String>>[];
  final rss = <String>[
    'https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml',
    'https://rss.nytimes.com/services/xml/rss/nyt/Science.xml',
    'https://rss.nytimes.com/services/xml/rss/nyt/Movies.xml',
    'https://rss.nytimes.com/services/xml/rss/nyt/Europe.xml',
    'https://rss.nytimes.com/services/xml/rss/nyt/Music.xml'
  ];

  final cancellationRequest = Completer<void>();
  unawaited(() async {
    await cancellationRequest.future;
    _message('Canceling');
    cts.cancel();
  }());

  void cancel() {
    if (!cancellationRequest.isCompleted) {
      cancellationRequest.complete();
    }
  }

  for (var i = 0; i < rss.length; i++) {
    final uri = Uri.parse(rss[i]);
    final task = Task.run(() async {
      final bytes = <int>[];
      token.throwIfCanceled();
      _message('Fetching feed: $uri');
      final request = Request('GET', uri);
      final task = Task.run(() => Client().send(request));
      StreamedResponse response;
      try {
        response = await task.withCancellation(token);
      } on TaskCanceledException {
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
        bytes.addAll(event);
      }

      final statusCode = response.statusCode;
      if (statusCode != 200) {
        throw Exception('Http error ($statusCode)');
      }

      // Simulate external cancellation request.
      // To initiate the cancellation of the remaining tasks
      cancel();

      final result = String.fromCharCodes(bytes);
      _message('Processing feed: $uri');
      await Future<void>.delayed(Duration(seconds: 1));
      return result;
    });

    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    print('-' * 40);
    print('${task.toString()}: ${task.status.name}');
    if (task.isSuccessful) {
      final value = await task;
      final text = value;
      final length = text.length < 80 ? text.length : 80;
      print('Data ${text.substring(0, length)}');
    } else {
      print('No data');
    }
  }
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}
