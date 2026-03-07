import 'dart:async';

import 'package:http/http.dart' as http;
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

  final cancellationRequest = Completer<void>()
    // ignore: unawaited_futures
    ..future.then((_) {
      _message('Canceling');
      cts.cancel();
    });

  void cancel() {
    if (!cancellationRequest.isCompleted) {
      cancellationRequest.complete();
    }
  }

  for (var i = 0; i < rss.length; i++) {
    final task = Task.run(() async {
      final url = Uri.parse(rss[i]);
      final bytes = <int>[];
      print('Fetching feed: $url');
      token.throwIfCancelled();
      final client = http.Client();
      try {
        final request = http.Request('GET', url);
        final response = await client.send(request);
        final stream = response.stream;
        // === listen to stream ===
        final it = StreamIterator(stream);
        final handler = token.addHandler(it.cancel);
        try {
          while (await it.moveNext()) {
            bytes.addAll(it.current);
          }
        } finally {
          token.removerHandler(handler);
          await it.cancel();
        }
        // === listen to stream ===
      } finally {
        // Simulate external cancel request
        cancel();

        print('Close client');
        client.close();
      }

      token.throwIfCancelled();
      final result = String.fromCharCodes(bytes);
      print('Processing feed: $url');
      await Future<void>.delayed(Duration(seconds: 1));
      return result;
    });

    tasks.add(task);
  }

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    print('-' * 40);
    print('${task.toString()}: ${task.state.name}');
    if (task.isCompleted) {
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
