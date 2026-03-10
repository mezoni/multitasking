import 'dart:async';

import 'package:defer/defer.dart';
import 'package:http/http.dart' as http;
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/stream/cancellable_stream_iterator.dart';

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
      final uri = Uri.parse(rss[i]);
      final bytes = <int>[];
      _message('Fetching feed: $uri');

      token.throwIfCancelled();
      final client = http.Client();

      await token.runGuarded(
        onCancel: client.close,
        () async {
          await defer(() async {
            client.close();
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
        },
      );

      token.throwIfCancelled();

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
