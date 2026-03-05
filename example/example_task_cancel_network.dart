import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:multitasking/extra/for_each.dart';
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
        await ForEach(stream, token, (event) {
          bytes.addAll(event);
          return true;
        }).wait;
      } finally {
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

  Timer(Duration(seconds: 4), () {
    _message('Cancelling');
    cts.cancel();
  });

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
