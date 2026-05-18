import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  {
    _header('Handle cancel');
    final s1 = Stream.fromIterable([1, 2, 3]);
    final completion = StreamCompletion();
    final s2 = s1.withCompletion(completion);

    unawaited(() async {
      await for (final event in s2) {
        print(event);
        if (event == 2) {
          print('break');
          break;
        }
      }
    }());

    final status = await completion.wait();
    print('Status: $status');
  }

  {
    _header('Handle done');
    final s1 = Stream.fromIterable([1, 2, 3]);
    final completion = StreamCompletion();
    final s2 = s1.withCompletion(completion);

    unawaited(() async {
      await for (final event in s2) {
        print(event);
      }
    }());

    final status = await completion.wait();
    print('Status: $status');
  }

  {
    _header('Handle error');
    Iterable<int> numbers() sync* {
      for (var i = 1; i < 3; i++) {
        yield i;
      }

      print('throw Exception()');
      throw Exception();
    }

    final s1 = Stream.fromIterable(numbers());
    final completion = StreamCompletion();
    final s2 = s1.withCompletion(completion);

    Future<void> listen() async {
      await for (final event in s2) {
        print(event);
      }
    }

    await listen().catchError((e) {});
    final status = await completion.wait();
    print('Status: $status');
    if (status is StreamStatusError) {
      print('Error: ${status.error}');
    }
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}
