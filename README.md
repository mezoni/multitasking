# Multitasking

Cooperative multitasking using asynchronous tasks.

Version: 2.0.0

[![Pub Package](https://img.shields.io/pub/v/multitasking.svg)](https://pub.dev/packages/multitasking)
[![Pub Monthly Downloads](https://img.shields.io/pub/dm/multitasking.svg)](https://pub.dev/packages/multitasking/score)
[![GitHub Issues](https://img.shields.io/github/issues/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/issues)
[![GitHub Forks](https://img.shields.io/github/forks/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/forks)
[![GitHub Stars](https://img.shields.io/github/stars/mezoni/v.svg)](https://github.com/mezoni/multitasking/stargazers)
[![GitHub License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://raw.githubusercontent.com/mezoni/multitasking/main/LICENSE)

## About this software

Cooperative multitasking using asynchronous tasks.  
The tasks is implemented using the following standard core classes:  

- [Zone](https://api.dart.dev/dart-async/Zone-class.html)
- [Zone specification](https://api.dart.dev/dart-async/ZoneSpecification-class.html)
- [Future](https://api.dart.dev/dart-async/Future-class.html)
- [Finalizer](https://api.dart.dev/dart-core/Finalizer-class.html)

## Practical use

Tasks are very lightweight objects. The actions performed by tasks are not much slower than those performed by futures.

A [Task] is an object representing some operation that will complete in the future.\
Tasks are executed asynchronously and cooperatively.\
Cooperative multitasking is a concurrency model where tasks voluntarily yield control (using `await`).

The result of a task execution is the result of computing the value of the task action. It can be either a value or an exception.\
The task itself is an object of [Future] that wraps the result of the computation.\
The main difference between the task and the [Future] is as follows:

**The task does not begin executing the computation immediately after it is created**.\
The task supports delayed start. Or it may never even be started.\
After the computation is completed, the task captures the result of the computation.

**In case of completion with an exception, the task does not propagate this exception to the unhandled exception handler immediately.**\
This unobserved exception is stored in the relevant task object instance until the task is aware that an exception has been observed.\
If the task isn not aware that an exception was observed, this exception will be propagated in the task finalizer ([Finalizer]).\
If the finalizer is not executed by runtime (due to Dart SDK limitations), the exception will remain unobserved.\
For this reason, due to the limited functionality of the finalizer, it is recommended to always observe task exceptions (detecting, catching, handling).

Exceptions in task can be observed in one of the following ways:

- `await task`
- `task.future`
- `Task.waitAll()`
- `task.asStream()` (inherited from [Future])
- `task.catchError()` (inherited from [Future])
- `task.then()` (inherited from [Future])
- `task.timeout()` (inherited from [Future])
- `task.whenComplete()` (inherited from [Future])

It all comes down to the fact that when accessing the [future] field of a task, an instance of the [Future] object is created and at that moment its life cycle begins.

## Examples of the main features of the `Task`

Task have features that extend, complement, or modify the functionality of futures.

Remark: All examples below were run during the creation of this document and contain actual output to the standard output streams (stdout and stderr).

**The task do not throw exceptions at the completion point in case of unsuccessful completion.**

Example with `Future`:

[example/example_future.dart](https://github.com/mezoni/multitasking/blob/main/example/example_future.dart)

```dart
import 'dart:async';

Future<void> main() async {
  final task = Future<int>(() => throw 'Error');

  print('Do some work');
  await Future<void>.delayed(Duration(seconds: 1));
  print('Work completed');

  try {
    final result = await task;
    print('Result: $result');
  } catch (e) {
    print(e);
  }
}

```

Output:

```txt
Do some work
Unhandled exception:
Error
#0      main.<anonymous closure> (file:///home/andrew/prj/multitasking/example/example_future.dart:4:34)
#1      new Future.<anonymous closure> (dart:async/future.dart:260:40)
#2      Timer._createTimer.<anonymous closure> (dart:async-patch/timer_patch.dart:18:15)
#3      _Timer._runTimers (dart:isolate-patch/timer_impl.dart:423:19)
#4      _Timer._handleMessage (dart:isolate-patch/timer_impl.dart:454:5)
#5      _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:193:12)

```

The same example with task:

[example/example_task_await.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_await.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(() => throw 'Error');

  print('Do some work');
  await Future<void>.delayed(Duration(seconds: 1));
  print('Work completed');

  try {
    final result = await task;
    print('Result: $result');
  } catch (e) {
    print(e);
  }
}

```

Output:

```txt
Do some work
Work completed
Error

```

A failed task does not affect the execution of other code (`Do some work`) if the task object instance is referenced.  
The task will not throw an exception until the executing code accesses the `future` field (directly or indirectly, e.g. using `await task`).

If the executing code do not access the `future` field and there are no references to the task object instance, an exception will be thrown during garbage collection when the task is finalized.  
Or it will never be thrown if the task finalization will not be performed (e.g. when the application terminates its work).

**For the current task, it is possible to specify the `onExit` handler inside the task body.**

The `OnExit` handler can be used to ensure the execution of some logical actions.

Example of `OnExit` handler:

[example/example_task_on_exit.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_on_exit.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(() {
    Object? handle;

    Task.onExit((task) {
      print('$task exit with status: \'${task.state.name}\'');
      if (handle != null) {
        print('$task frees up: \'handle\'');
      }
    });

    handle = Object();
    throw 'Error';
  });

  print('Do some work');
  await Future<void>.delayed(Duration(seconds: 1));
  print('Work completed');

  try {
    final result = await task;
    print('Result: $result');
  } catch (e) {
    print(e);
  }
}

```

Output:

```txt
Task(0) exit with status: 'failed'
Task(0) frees up: 'handle'
Do some work
Work completed
Error

```

**The name of the task can be specified.**

Example of using a task with the name:

[example/example_task_name.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_name.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(name: 'my task', () {
    return 1;
  });

  print(task.name);
  await task;
}

```

Output:

```txt
my task

```

**The task can be cancelled using a cancellation token.**

Canceling a task is a normal action that is supported by the implementation of the mechanism of task functioning.  
Canceling a task is safe for the task and the runtime. But that does not  mean it is safe for the application.  
For this reason, task cancellation is only performed in cases where the developer explicitly allows for cancellation.  

There are different ways to handle task cancellation.

```dart
token.throwIfCancelled();
```

```dart
if (token.isCancelled) {
  // Handle cancellation
  throw TaskCanceledError();
}
```

Remark:  
The terms `parent task` and `child task` are rather arbitrary, since there is no real relationship between these tasks.  
They are used to simplify the logical understanding of the interaction of tasks.  
The interaction logic is completely determined by the developer.

**The task can be cancelled as a group of tasks.**

Example of cancelled a group of tasks in case of any failure in any task.  

[example/example_task_cancel_group_by_failure.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_group_by_failure.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  late AnyTask parent;
  final group = <Task<int>>[];

  void onExit(AnyTask task) {
    if (task.state != TaskState.completed) {
      cts.cancel();
    }
  }

  parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: $task (${task.state.name})');
      onExit(task);
    });

    for (var i = 1; i <= 3; i++) {
      final t = Task<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: $task (${task.state.name})');
          onExit(task);
        });

        final n = i;
        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;

          token.throwIfCancelled();

          await Future<void>.delayed(Duration(seconds: 2));
          if (n == 1) {
            throw 'Failure in ${Task.current}';
          }
        }

        print('${Task.current} work done');
        return result;
      });

      group.add(t);
    }

    for (final task in group) {
      task.start();
      await Task.sleep();
    }

    await Task.waitAll(group);
  });

  try {
    await parent;
  } catch (e) {
    print(e);
  }
}

```

Output:

```txt
Task('Child 1', 2) works: 0 of 4
Task('Child 2', 3) works: 0 of 4
Task('Child 3', 4) works: 0 of 4
On exit: Task('Child 1', 2) (failed)
Task('Child 2', 3) works: 1 of 4
On exit: Task('Child 2', 3) (cancelled)
Task('Child 3', 4) works: 1 of 4
On exit: Task('Child 3', 4) (cancelled)
On exit: Task('Parent', 0) (failed)
One or more errors occurred. (Failure in Task('Child 1', 2)) (TaskCanceledError) (TaskCanceledError)

```

Example of cancelled a group of tasks while working with the network.  

[example/example_task_cancel_network.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_network.dart)

```dart
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

```

Output:

```txt
Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml
Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Science.xml
Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Movies.xml
Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Europe.xml
Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Music.xml
Close client
Processing feed: https://rss.nytimes.com/services/xml/rss/nyt/Music.xml
Close client
Processing feed: https://rss.nytimes.com/services/xml/rss/nyt/Science.xml
Close client
Close client
Close client
One or more errors occurred. (TaskCanceledError) (TaskCanceledError) (TaskCanceledError)
----------------------------------------
Task(0): cancelled
No data
----------------------------------------
Task(2): completed
Data <?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/element
----------------------------------------
Task(3): cancelled
No data
----------------------------------------
Task(4): cancelled
No data
----------------------------------------
Task(5): completed
Data <?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/element

```

Another example of cancelled a group of tasks while working with the network.  

[example/example_task_cancel_long_network.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_long_network.dart)

```dart
import 'dart:async';
import 'dart:io';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;
  final list = [
    (
      '3.11.1',
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.1/sdk/dartsdk-windows-x64-release.zip'
    ),
    (
      '3.10.9',
      'https://storage.googleapis.com/dart-archive/channels/stable/release/3.10.9/sdk/dartsdk-windows-x64-release.zip'
    )
  ];

  final tasks = <AnyTask>[];
  for (final element in list) {
    final url = Uri.parse(element.$2);
    final filename = element.$1;
    final task = _download(url, filename, token);
    tasks.add(task);
  }

  // User request to cancel
  Timer(Duration(seconds: 2), cts.cancel);

  try {
    await Task.waitAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    if (task.state == TaskState.completed) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    final client = HttpClient();
    final bytes = <int>[];

    token.throwIfCancelled();
    token.addHandler(Task.current, (task) {
      // If [force] is `true` any active/ connections will be closed to
      // immediately release all resources.
      client.close(force: true);
    });

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        await for (final event in response) {
          if (token.isCancelled) {
            client.close(force: true);
            break;
          }

          bytes.addAll(event);
        }
      } else {
        throw 'HTTP error: ${response.statusCode}';
      }
    } finally {
      print('Close client');
      token.removeHandler(Task.current);
      client.close();
    }

    token.throwIfCancelled();

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

```

Output:

```txt
Close client
Close client
One or more errors occurred. (HttpException: Connection closed while receiving data, uri = https://storage.googleapis.com/dart-archive/channels/stable/release/3.11.1/sdk/dartsdk-windows-x64-release.zip) (HttpException: Connection closed while receiving data, uri = https://storage.googleapis.com/dart-archive/channels/stable/release/3.10.9/sdk/dartsdk-windows-x64-release.zip)

```
