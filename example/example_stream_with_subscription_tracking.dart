import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  {
    _header('Listen/cancel');
    final stream = Stream.periodic(Duration(seconds: 1), (count) {
      return count;
    }).withSubscriptionTracking((event) {
      print(event.name);
    });

    final sub = stream.listen(print);
    await Future<void>.delayed(Duration(seconds: 3));
    await sub.cancel();
  }

  {
    _header('Listen/pause/resume/cancel');
    final stream = Stream.periodic(Duration(seconds: 1), (count) {
      return count;
    }).withSubscriptionTracking((event) {
      print(event.name);
    });

    final sub = stream.listen(print);
    await Future<void>.delayed(Duration(seconds: 1));
    sub.pause();
    await Future<void>.delayed(Duration(seconds: 1));
    sub.resume();
    await Future<void>.delayed(Duration(seconds: 1));
    await sub.cancel();
  }

  {
    _header('Await for/break');
    final stream = Stream.periodic(Duration(seconds: 1), (count) {
      return count;
    }).withSubscriptionTracking((event) {
      print(event.name);
    });

    await for (final event in stream) {
      print(event);
      if (event == 3) {
        print('break;');
        break;
      }
    }
  }

  {
    _header('Async*');
    Stream<int> gen() async* {
      for (var i = 0; i < 3; i++) {
        yield i;
        await Future<void>.delayed(Duration(seconds: 1));
      }
    }

    final stream = gen().withSubscriptionTracking((event) {
      print(event.name);
    });

    stream.listen(print);
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}
