import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      final uri = rss[i];
      final url = Uri.parse(uri);
      String? raw;
      print('Fetching feed: $url');
      final client = HttpClient();

      token.throwIfCancelled();

      try {
        final request = await client.getUrl(url);
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          raw = await response.transform(utf8.decoder).join();
        } else {
          throw 'HTTP error: ${response.statusCode}';
        }
      } finally {
        print('Close client');
        client.close();
      }

      token.throwIfCancelled();

      final result = raw;
      print('Processing feed: $url');
      await Future<void>.delayed(Duration(seconds: 1));
      return result;
    });

    tasks.add(task);
  }

  Timer(Duration(seconds: 4), cts.cancel);

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    print('-' * 40);
    print('$task: ${task.state.name}');
    if (task.state == TaskState.completed) {
      final value = await task;
      final text = '$value';
      final length = text.length < 80 ? text.length : 80;
      print('Data ${text.substring(0, length)}');
    } else {
      print('No data');
    }
  }
}
