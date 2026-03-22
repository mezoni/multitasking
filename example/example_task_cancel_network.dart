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
      _message('Fetching feed: $uri');

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

        try {
          await response.stream.listen(bytes.addAll).asFuture<void>();
        } on RequestAbortedException {
          throw TaskCanceledException();
        }
      }

      await token.runCancelable(abortTrigger.complete, get);

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
