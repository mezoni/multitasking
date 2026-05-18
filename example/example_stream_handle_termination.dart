import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  {
    _header('Handle cancel');
    final s1 = Stream.fromIterable([1, 2, 3]);
    final s2 = _addDemoExitHandlers(s1);
    await for (final event in s2) {
      print(event);
      if (event == 2) {
        print('break');
        break;
      }
    }
  }

  {
    _header('Handle done');
    final s1 = Stream.fromIterable([1, 2, 3]);
    final s2 = _addDemoExitHandlers(s1);
    await for (final event in s2) {
      print(event);
    }
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
    final s2 = _addDemoExitHandlers(s1);
    Future<void> listen() async {
      await for (final event in s2) {
        print(event);
      }
    }

    await listen().catchError((e) {});
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

Stream<T> _addDemoExitHandlers<T>(Stream<T> stream) {
  return stream.handleTermination(() {
    print('onTerminate');
  }, onCancel: () {
    print('onCancel');
  }, onDone: () {
    print('onDone');
  }, onError: (error, stackTrace) {
    print('onError');
  });
}
