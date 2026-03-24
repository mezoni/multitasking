# Multitasking

Cooperative multitasking using asynchronous tasks and synchronization primitives, with the ability to safely cancel groups of nested tasks performing I/O wait or listen operations.

Version: 4.3.0

[![Pub Package](https://img.shields.io/pub/v/multitasking.svg)](https://pub.dev/packages/multitasking)
[![Pub Monthly Downloads](https://img.shields.io/pub/dm/multitasking.svg)](https://pub.dev/packages/multitasking/score)
[![GitHub Issues](https://img.shields.io/github/issues/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/issues)
[![GitHub Forks](https://img.shields.io/github/forks/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/forks)
[![GitHub Stars](https://img.shields.io/github/stars/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/stargazers)
[![GitHub License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://raw.githubusercontent.com/mezoni/multitasking/main/LICENSE)

![Producer/consumer problem: Monitor and 2 condition variables operation](https://i.imgur.com/gkMEGId.gif)

Producer/consumer problem: Monitor and 2 condition variables operation.

![example_task_download_file.dart](https://i.imgur.com/IBny2xe.gif)

[example_task_download_file.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_download_file.dart)

- [Multitasking](#multitasking)
  - [About this software](#about-this-software)
  - [Practical use](#practical-use)
    - [The task does not begin executing the computation immediately after it is created](#the-task-does-not-begin-executing-the-computation-immediately-after-it-is-created)
    - [In case of completion with an exception, the task does not propagate this exception to the unhandled exception handler immediately](#in-case-of-completion-with-an-exception-the-task-does-not-propagate-this-exception-to-the-unhandled-exception-handler-immediately)
  - [Examples of the main features of the `Task`](#examples-of-the-main-features-of-the-task)
    - [The task do not throw exceptions at the completion point in case of unsuccessful completion](#the-task-do-not-throw-exceptions-at-the-completion-point-in-case-of-unsuccessful-completion)
    - [For the current task, it is possible to specify the `onExit` handler inside the task body](#for-the-current-task-it-is-possible-to-specify-the-onexit-handler-inside-the-task-body)
    - [The task immediately propagates an exception if it is an unhandled exception](#the-task-immediately-propagates-an-exception-if-it-is-an-unhandled-exception)
    - [The task result can be accessed synchronously after the task is completed](#the-task-result-can-be-accessed-synchronously-after-the-task-is-completed)
    - [The name of the task can be specified](#the-name-of-the-task-can-be-specified)
    - [Tasks can be waited for in different ways](#tasks-can-be-waited-for-in-different-ways)
    - [Tasks can be waited for as a stream](#tasks-can-be-waited-for-as-a-stream)
    - [The task zone provides access to statistics of the operations in the zone](#the-task-zone-provides-access-to-statistics-of-the-operations-in-the-zone)
    - [The task can be canceled using a cancellation token](#the-task-can-be-canceled-using-a-cancellation-token)
    - [The task can be canceled during `Task.delay()`](#the-task-can-be-canceled-during-taskdelay)
    - [The task can be canceled as a group of tasks](#the-task-can-be-canceled-as-a-group-of-tasks)
    - [The task can be canceled while listening to the stream](#the-task-can-be-canceled-while-listening-to-the-stream)
    - [The group of tasks can be safely canceled while working with the network](#the-group-of-tasks-can-be-safely-canceled-while-working-with-the-network)
    - [The tasks can be safely canceled during long running network operation](#the-tasks-can-be-safely-canceled-during-long-running-network-operation)
    - [Tasks can be used with `Isolate`, and all of them can be safely canceled](#tasks-can-be-used-with-isolate-and-all-of-them-can-be-safely-canceled)
  - [Synchronization primitives](#synchronization-primitives)
    - [Counting semaphore](#counting-semaphore)
    - [Binary semaphore](#binary-semaphore)
    - [Condition variable](#condition-variable)
    - [Reentrant lock](#reentrant-lock)
    - [Lock interface](#lock-interface)
    - [Multiple write single read object](#multiple-write-single-read-object)
    - [Manual reset event](#manual-reset-event)

## About this software

Cooperative multitasking using asynchronous tasks and synchronization primitives, with the ability to safely cancel groups of nested tasks performing I/O wait or listen operations.  
The tasks is implemented using the following standard core classes:  

- [Zone](https://api.dart.dev/dart-async/Zone-class.html)
- [Zone specification](https://api.dart.dev/dart-async/ZoneSpecification-class.html)
- [Completer](https://api.dart.dev/dart-async/Completer-class.html)
- [Future](https://api.dart.dev/dart-async/Future-class.html)
- [Finalizer](https://api.dart.dev/dart-core/Finalizer-class.html)

Are the tasks safe and reliable?  
Yes, because the tasks have a very simple construction and operating mechanism.  
In a few words, the task life cycle can be described as follows:

- A task is created with an action in the form of a function that must be executed
- The initial state of a task is the state in which the action has not yet started to execute
- After receiving a command to start executing an action, the task waits for the action  (`function`) to complete its execution
- After completing this `function`, the task (using `Completer<T>`) puts itself into one of the states indicating the completion of the task
- After this, the task result (or error) becomes available through a variable `future` with the value type `Future`

To simplify working with the task, it itself is an instance of an object that implements the `Future` interface.  
In this case, the task does not replace `Future<T>` (doesn't reinvent the wheel), it uses the standard `Completer<T>` and its field `future`.  

Thus, a `Task<T>` is an object that implements the `Future<T>`  interface by using `Completer<T>`.  
This task only adds the ability (to `Future<T>`) to start its execution on command and track the completion state of the action.

The main purpose of tasks is to conveniently manage a large number of asynchronous tasks with nested subtasks running simultaneously and cooperatively, with the ability to perform their soft, controlled, and broadly functional stop (cancellation), and the ability to write a task destructor in the body of the task itself.  
In this way, a request to cancel tasks (and all nested subtasks and all internal critically important operations) can be handled in such a way that everything happens harmoniously and completely safely.  
A cancellation request is made using a special token. A task cancellation token can be used synchronously (blocking) or asynchronously (via a subscription, which attaches a handler only for the duration of a critical and potentially very long operation).

## Practical use

Tasks are very lightweight objects. The actions performed by tasks are not much slower than those performed by futures.

A [Task] is an object representing some operation that will complete in the future.\
Tasks are executed asynchronously and cooperatively.\
Cooperative multitasking is a concurrency model where tasks voluntarily yield control (using `await`).

The result of a task execution is the result of computing the value of the task action. It can be either a value or an exception.\
The task itself is an object of [Future] that wraps the result of the computation.\
The main difference between the task and the [Future] is as follows:

- Task can be created in unstarted state and can be started by demand
- If the task execution fails, the exception will not be propagated immediately
- For a task, it is possible to track the current state through the `state` property or through the `is{State}` property (for example, `isRunning`)

### The task does not begin executing the computation immediately after it is created

The task supports delayed start. Or it may never even be started.\
After the computation is completed, the task captures the result of the computation.

### In case of completion with an exception, the task does not propagate this exception to the unhandled exception handler immediately

This unobserved exception is stored in the relevant task object instance until the task is aware that an exception has been observed.\
If the task isn not aware that an exception was observed, this exception will be propagated in the task finalizer ([Finalizer]).\
If the finalizer is not executed by runtime (due to Dart SDK limitations), the exception will remain unobserved.\
For this reason, due to the limited functionality of the finalizer, it is recommended to always observe task exceptions (detecting, catching, handling).

Exceptions in task can be observed in one of the following ways:

- `await task`
- `Task.waitAll()`
- `Task.whenAll()`
- `Task.whenAny()`
- `task.asStream()` (inherited from [Future])
- `task.catchError()` (inherited from [Future])
- `task.then()` (inherited from [Future])
- `task.timeout()` (inherited from [Future])
- `task.whenComplete()` (inherited from [Future])

## Examples of the main features of the `Task`

Task have features that extend, complement, or modify the functionality of futures.

Remark: All examples below were run during the creation of this document and contain actual output to the standard output streams (stdout and stderr).

### The task do not throw exceptions at the completion point in case of unsuccessful completion

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

### For the current task, it is possible to specify the `onExit` handler inside the task body

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
      print("${task.toString()} exit with status: '${task.state.name}'");
      if (handle != null) {
        print("${task.toString()} frees up: 'handle'");
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

### The task immediately propagates an exception if it is an unhandled exception

An unhandled exception is considered to be an exception (except `TaskCanceledError`) that occurs after a task has completed.  
Since each task is executed in a separate zone, after the task is completed, timers (if any were created) may remain in the zone created for the task execution.  
If an exception occurs within these timers, it is considered unhandled and will be immediately propagated to the parent zone.

Example of handling unhandled exceptions:

[example/example_task_handle_unhandled_error.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_handle_unhandled_error.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    final task = Task.run(() {
      Task.onExit((task) {
        throw 'Error on exit';
      });

      Timer(const Duration(), () {
        throw 'Error in timer';
      });
      throw 'Error in body';
    });

    try {
      await task;
    } catch (e) {
      print('Task error: $e');
    }
  }, (error, stack) {
    print('Unhandled error: $error');
  });
}

```

Output:

```txt
Unhandled error: Error on exit
Task error: Error in body
Unhandled error: Error in timer

```

### The task result can be accessed synchronously after the task is completed

An example of a synchronous access to a task result:

[example/example_task_result.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_result.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(() {
    return 42;
  });

  await task;
  print(task.result);
}

```

Output:

```txt
42

```

### The name of the task can be specified

Example of using a task with the name:

[example/example_task_name.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_name.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run(name: 'my task', () {
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

### Tasks can be waited for in different ways

Example of waiting for in different ways:

[example/example_task_wait_in_different_ways.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_wait_in_different_ways.dart)

```dart
import 'dart:async';

import 'package:multitasking/misc/progress.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork(1, 200),
    doSomeWork(2, 300),
  ];

  final progress = Progress((({int count, int total}) info) {
    final (:count, :total) = info;
    final percent = (total == 0 ? 100 : 100 * count / total).toStringAsFixed(2);
    print('Ready: $percent%');
  });

  print('whenAny()');
  final firstTask = await Task.whenAny(tasks, progress: progress);
  print('First task: ${firstTask.toString()} (${firstTask.state.name})');
  try {
    final result = await firstTask;
    print('First result: $result');
  } catch (e) {
    print('Error: $e');
  }

  print('Tasks:');
  print(tasks.map((e) {
    return '${e.toString()} (${e.state.name})';
  }).join(', '));

  print('whenAll()');
  try {
    final results = await Task.whenAll(tasks);
    print('Results: $results');
  } catch (e) {
    print('Error: $e');
  }

  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    var s = '${task.toString()}: ${task.state.name}';
    if (task.isCompleted) {
      s += ', result: ${task.result}';
    } else {
      s += ', exception: ${task.exception!.error}';
    }

    print(s);
  }
}

Task<int> doSomeWork(int n, int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return n;
  });
}

Task<int> doSomeWorkWithError(int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    throw StateError('Some error');
  });
}

```

Output:

```txt
whenAny()
Ready: 33.33%
First task: Task(0) (failed)
Error: Bad state: Some error
Tasks:
Task(0) (failed), Task(1) (running), Task(2) (running)
whenAll()
Ready: 66.67%
Ready: 100.00%
Error: AggregateError: One or more errors occurred. (Bad state: Some error)
Task(0): failed, exception: Bad state: Some error
Task(1): completed, result: 1
Task(2): completed, result: 2

```

### Tasks can be waited for as a stream

Example of waiting for tasks as a stream

[example/example_task_stream.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stream.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final tasks = [
    doSomeWorkWithError(100),
    doSomeWork(1, 200),
    doSomeWork(2, 300),
  ];

  await for (final task in Task.whenEach(tasks)) {
    print('${task.toString()} ${task.state.name}');
    if (task.isCompleted) {
      final result = await task;
      print('${task.toString()} result $result');
    }
  }
}

Task<int> doSomeWork(int n, int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return n;
  });
}

Task<int> doSomeWorkWithError(int ms) {
  return Task.run(() async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    throw StateError('Some error');
  });
}

```

Output:

```txt
Task(0) failed
Task(1) completed
Task(1) result 1
Task(2) completed
Task(2) result 2

```

### The task zone provides access to statistics of the operations in the zone

Example of accessing task zone statistics:

[example/example_task_zone_stats.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_zone_stats.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task(name: 'my task', () async {
    print('-' * 40);
    print('Task started');
    Timer(Duration(milliseconds: 400), () {});
    await Future<void>.delayed(const Duration());
    return 42;
  });

  final zoneStats = task.zoneStats;
  if (zoneStats != null) {
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      print('-' * 40);
      if (zoneStats.isZoneActive || !task.isStarted) {
        print('Active microtasks: ${zoneStats.activeMicrotasks}');
        print('Active periodic timers: ${zoneStats.activePeriodicTimers}');
        print('Active timers: ${zoneStats.activeTimers}');
      } else {
        timer.cancel();
        print('Scheduled microtasks: ${zoneStats.scheduledMicrotasks}');
        print('Created periodic timers: ${zoneStats.createdPeriodicTimers}');
        print('Created timers: ${zoneStats.createdTimers}');
      }
    });
  }

  await Future<void>.delayed(Duration(milliseconds: 100));
  await task.start();
  await task;
}

```

Output:

```txt
----------------------------------------
Active microtasks: 0
Active periodic timers: 0
Active timers: 0
----------------------------------------
Task started
----------------------------------------
Active microtasks: 0
Active periodic timers: 0
Active timers: 1
----------------------------------------
Active microtasks: 0
Active periodic timers: 0
Active timers: 1
----------------------------------------
Active microtasks: 0
Active periodic timers: 0
Active timers: 1
----------------------------------------
Active microtasks: 0
Active periodic timers: 0
Active timers: 1
----------------------------------------
Scheduled microtasks: 0
Created periodic timers: 0
Created timers: 2

```

### The task can be canceled using a cancellation token

Canceling a task is a normal action that is supported by the implementation of the mechanism of task functioning.  
Canceling a task is safe for the task and the runtime. But that does not  mean it is safe for the application.  
For this reason, task cancellation is only performed in cases where the developer explicitly allows for cancellation.  

There are different ways to handle task cancellation.

```dart
token.throwIfCanceled();
```

```dart
if (token.isCanceled) {
  // Handle cancellation
  throw TaskCanceledError();
}
```

### The task can be canceled during `Task.delay()`

All that is required for this is to pass the token as an argument to method `Task.delay()`.

Example of cancelling a task during task sleep`Task.delay()`:

[example/example_task_cancel_during_delay.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_during_delay.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main(List<String> args) async {
  final cts = CancellationTokenSource();
  final token = cts.token;

  var count = 0;
  final task = Task.run(() async {
    while (true) {
      count++;
      await Task.delay(0, token);
    }
  });

  cts.cancelAfter(Duration(seconds: 1));

  try {
    await task;
  } catch (e) {
    print(e);
  }

  _message('count: $count');
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
TaskCanceledException
main(): count: 216772

```

Remark:  
The terms `parent task` and `child task` are rather arbitrary, since there is no real relationship between these tasks.  
They are used to simplify the logical understanding of the interaction of tasks.  
The interaction logic is completely determined by the developer.

### The task can be canceled as a group of tasks

Example of canceling a group of tasks in case of any failure in any task:

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
    if (!task.isCompleted) {
      cts.cancel();
    }
  }

  parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: ${task.toString()} (${task.state.name})');
      onExit(task);
    });

    for (var i = 1; i <= 3; i++) {
      final t = Task<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: ${task.toString()} (${task.state.name})');
          onExit(task);
        });

        final n = i;
        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;

          token.throwIfCanceled();

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
      await task.start();
      await Task.sleep();
    }

    await Task.whenAll(group);
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
On exit: Task('Child 2', 3) (canceled)
Task('Child 3', 4) works: 1 of 4
On exit: Task('Child 3', 4) (canceled)
On exit: Task('Parent', 0) (failed)
AggregateError: One or more errors occurred. (Failure in Task('Child 1', 2)) (TaskCanceledException) (TaskCanceledException)

```

### The task can be canceled while listening to the stream

Example of canceling the emulation of the `await for` statement using `ForEach` class:

[example/example_task_cancel_during_stream_iteration.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_during_stream_iteration.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main(List<String> args) async {
  final controller = StreamController<int>.broadcast();

  final stream = controller.stream;
  final cts = CancellationTokenSource();
  final token = cts.token;

  var n = 0;
  Timer.periodic(Duration(seconds: 1), (timer) {
    print('Send event: $n');
    controller.add(n++);
    if (n > 5) {
      print('Stopping the controller');
      timer.cancel();
      unawaited(controller.close());
    }
  });

  Timer(Duration(seconds: 3), () {
    _message('Cancellation requested');
    cts.cancel();
  });

  final tasks = <Task<int>>[];
  for (var i = 0; i < 3; i++) {
    final task = _doWork(stream, token, testBreak: i == 2);
    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    if (task.isCompleted) {
      final result = await task;
      _message('Result of ${task.toString()}: $result');
    }
  }
}

Task<int> _doWork(Stream<int> stream, CancellationToken token,
    {bool testBreak = false}) {
  return Task.run(() async {
    await Task.sleep();
    final list = <int>[];

    token.throwIfCanceled();
    StreamSubscription<int>? subscription;
    subscription = stream.listen((data) {
      _message('Received event: $data');
      list.add(data);
      if (list.length == 1 && testBreak) {
        _message('I want to break free...');
        // break;
        unawaited(subscription!.cancel());
      }
    });

    await token.runCancelable(subscription.cancel, subscription.asFuture<void>);

    await Task.sleep();
    _message('Processing data: $list');
    if (testBreak) {
      return list.length;
    }

    await Future<void>.delayed(Duration(seconds: 1));
    return list.length;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Send event: 0
Task(0): Received event: 0
Task(1): Received event: 0
Task(2): Received event: 0
Task(2): I want to break free...
Send event: 1
Task(0): Received event: 1
Task(1): Received event: 1
Send event: 2
Task(0): Received event: 2
Task(1): Received event: 2
main(): Cancellation requested
Send event: 3
Send event: 4
Send event: 5
Stopping the controller

```

### The group of tasks can be safely canceled while working with the network

An example of group of tasks cancellation while working with the network:

[example/example_task_cancel_network.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_network.dart)

```dart
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
    await Task.whenAll(tasks);
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

```

Output:

```txt
Task(0): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml
Task(1): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Science.xml
Task(2): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Movies.xml
Task(3): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Europe.xml
Task(4): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Music.xml
Task(1): Processing feed: https://rss.nytimes.com/services/xml/rss/nyt/Science.xml
main(): Canceling
AggregateError: One or more errors occurred. (TaskCanceledException) (TaskCanceledException) (TaskCanceledException) (TaskCanceledException)
----------------------------------------
Task(0): canceled
No data
----------------------------------------
Task(1): completed
Data <?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/element
----------------------------------------
Task(2): canceled
No data
----------------------------------------
Task(3): canceled
No data
----------------------------------------
Task(4): canceled
No data

```

### The tasks can be safely canceled during long running network operation

An example of task cancellation during long network operation:

[example/example_task_cancel_long_network.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_long_network.dart)

```dart
import 'dart:async';

import 'package:http/http.dart';
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
  Timer(Duration(seconds: 2), () {
    print('Canceling...');
    cts.cancel();
  });

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print('$e');
  }

  for (final task in tasks) {
    if (task.isCompleted) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    final bytes = <int>[];

    Task.onExit((task) {
      print('${task.toString()}: ${task.state.name}');
      _message('Downloaded: ${bytes.length}');
    });

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

    // Save file to disk
    await Future<void>.delayed(Duration(seconds: 1));
    return filename;
  });
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Canceling...
Task(0): canceled
Task(0): Downloaded: 2891775
Task(2): canceled
Task(2): Downloaded: 2801664
AggregateError: One or more errors occurred. (TaskCanceledException) (TaskCanceledException)

```

### Tasks can be used with `Isolate`, and all of them can be safely canceled

This example is not fundamental and is used for demonstration purposes only.

An example of using tasks with isolates and their simultaneous cancellation:

[example/example_task_cancel_isolate.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_isolate.dart)

```dart
import 'dart:async';
import 'dart:isolate';

import 'package:defer/defer.dart';
import 'package:multitasking/multitasking.dart';

void main(List<String> args) async {
  var cts = CancellationTokenSource();
  await bigWork(cts);

  cts = CancellationTokenSource();
  Timer(Duration(seconds: 2), () {
    _message('Canceling...');
    cts.cancel();
  });

  await bigWork(cts);
}

Future<void> bigWork(CancellationTokenSource cts) async {
  _message('-' * 40);
  final token = cts.token;

  final tasks = <AnyTask>[];
  for (var i = 0; i < 5; i++) {
    final task = Task.run(() async {
      final controller = StreamController<int>();
      final results = <int>[];
      controller.stream.listen(results.add);

      await defer(controller.close, () async {
        await _computeUsingIsolate(doWork, i, controller.sink, token);
      });

      _message('Received result: $results');
    });

    _message('Adding task $i');
    tasks.add(task);
    // Allow task to start
    await Task.sleep();
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

Future<void> doWork((SendPort, int) message) async {
  final (sendPort, arg) = message;
  final port = ReceivePort();
  try {
    final cts = _createCancellationTokenSource(port, sendPort);
    final token = cts.token;
    print("Isolate started: ${Isolate.current.hashCode}");
    var result = arg;

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration(milliseconds: 250));
      token.throwIfCanceled();
      result++;
      //throw 'Error';
    }

    //throw 'Error';
    sendPort.send(result);
  } finally {
    port.close();
  }
}

Future<void> _computeUsingIsolate<T, R>(
  void Function((SendPort, T)) computation,
  T argument,
  Sink<R> sink,
  CancellationToken token,
) async {
  final port = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final barrier = Completer<SendPort>();
  final resultCompleter = Completer<void>();
  void Function()? handler;

  final isolate = await Isolate.spawn(
    computation,
    (port.sendPort, argument),
    paused: true,
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  void closeAll() {
    if (!resultCompleter.isCompleted) {
      resultCompleter.complete();
    }

    token.removerHandler(handler);
    port.close();
    errorPort.close();
    exitPort.close();
  }

  errorPort.listen((message) {
    if (!resultCompleter.isCompleted) {
      final exception = message as List<Object?>;
      final error = exception[0]!;
      final stackTraceString = exception[1];
      StackTrace? stackTrace;
      if (stackTraceString is String) {
        stackTrace = StackTrace.fromString(stackTraceString);
      }

      resultCompleter.completeError(error, stackTrace);
    }
  });

  exitPort.listen((message) {
    closeAll();
  });

  isolate.resume(isolate.pauseCapability!);
  port.listen((message) {
    if (message is SendPort) {
      barrier.complete(message);
    } else {
      sink.add(message as R);
    }
  });

  final cancelPort = await barrier.future;
  handler = token.addHandler(() {
    cancelPort.send(null);
  });

  return resultCompleter.future;
}

CancellationTokenSource _createCancellationTokenSource(
  ReceivePort port,
  SendPort sendPort,
) {
  final cts = CancellationTokenSource();
  sendPort.send(port.sendPort);
  port.listen((message) {
    cts.cancel();
  });

  return cts;
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
main(): ----------------------------------------
main(): Adding task 0
Isolate started: 693425803
main(): Adding task 1
Isolate started: 905182430
main(): Adding task 2
main(): Adding task 3
Isolate started: 1006870447
main(): Adding task 4
Isolate started: 798679432
Isolate started: 260330579
Task(4): Received result: [13]
Task(1): Received result: [10]
Task(3): Received result: [12]
Task(5): Received result: [14]
Task(2): Received result: [11]
main(): ----------------------------------------
main(): Adding task 0
main(): Adding task 1
main(): Adding task 2
Isolate started: 802428445
main(): Adding task 3
Isolate started: 614209794
main(): Adding task 4
Isolate started: 133241999
Isolate started: 678367537
Isolate started: 79583466
main(): Canceling...
AggregateError: One or more errors occurred. (TaskCanceledException) (TaskCanceledException) (TaskCanceledException) (TaskCanceledException) (TaskCanceledException)

```

## Synchronization primitives

Synchronization primitives are mechanisms that synchronize the execution of multiple operations by locking their execution and putting them into a waiting state.  
In essence, these mechanisms imply either waiting for acquire the permit, followed by release this permit, or waiting for a signal without acquiring the permit. Or even waiting for a signal followed by acquiring the permit.  

Synchronization primitives do not require the use of tasks, they work with zones (`Zone`) and can be used in any applications.

### Counting semaphore

A  `CountingSemaphore` is a synchronization primitive that maintains a counter that represents the number of available permits.  
Acquire:  
If the counter is 0, the execution of the calling code is blocked until the count becomes greater than 0.  
Otherwise, the counter is decremented, and the calling code acquires a permit.  
Release:  
If any calling code was blocked from executing, that code will continue executing and acquire the permit.  
Otherwise, the counter is incremented.

Example with a limit of no more than 3 simultaneously executed operations:

[example/example_counting_semaphore.dart](https://github.com/mezoni/multitasking/blob/main/example/example_counting_semaphore.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/counting_semaphore.dart';

Future<void> main(List<String> args) async {
  final sem = CountingSemaphore(0, 3);
  final tasks = <AnyTask>[];
  _message('Round with asynchronous entry in the task body');
  for (var i = 0; i < 7; i++) {
    final task = Task.run(name: 'task $i', () async {
      // Asynchronous entry
      await Task.sleep();
      _message('acquire');
      await sem.acquire();
      try {
        _message('  acquired');
        await Task.sleep();
      } finally {
        _message('release');
        await sem.release();
      }
    });

    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }

  tasks.clear();
  print('-' * 40);
  _message('Round with synchronous entry in the task body');
  for (var i = 0; i < 7; i++) {
    final task = Task.run(name: 'task $i', () async {
      // Synchronous entry
      // await Task.sleep();
      _message('acquire');
      await sem.acquire();
      try {
        _message('  acquired');

        await Task.sleep();
      } finally {
        _message('release');
        await sem.release();
      }
    });

    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
main(): Round with asynchronous entry in the task body
task 0: acquire
task 0:   acquired
task 1: acquire
task 1:   acquired
task 2: acquire
task 2:   acquired
task 3: acquire
task 4: acquire
task 5: acquire
task 6: acquire
task 0: release
task 3:   acquired
task 1: release
task 4:   acquired
task 2: release
task 5:   acquired
task 3: release
task 6:   acquired
task 4: release
task 5: release
task 6: release
----------------------------------------
main(): Round with synchronous entry in the task body
task 0: acquire
task 1: acquire
task 2: acquire
task 3: acquire
task 4: acquire
task 5: acquire
task 6: acquire
task 0:   acquired
task 1:   acquired
task 2:   acquired
task 0: release
task 3:   acquired
task 1: release
task 4:   acquired
task 2: release
task 5:   acquired
task 3: release
task 6:   acquired
task 4: release
task 5: release
task 6: release

```

### Binary semaphore

A `BinarySemaphore` is a synchronization primitive with an integer value restricted to 0 or 1, representing locked (0) or unlocked (1) states.

Unlike a mutex, a semaphore is a counting-based synchronizer.  
If a semaphore is locked, it will be locked even for the current zone.

If a mutex is owned by a zone, it will not block this zone. It will count the number of times it is entered and leaved by zone before
releasing.

An example of using a binary semaphore as a locking mechanism:

[example/example_binary_semaphore.dart](https://github.com/mezoni/multitasking/blob/main/example/example_binary_semaphore.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';

Future<void> main(List<String> args) async {
  final sem = BinarySemaphore();
  final tasks = <AnyTask>[];

  for (var i = 0; i < 5; i++) {
    final task = Task.run(name: 'task $i', () async {
      await Task.sleep();
      _message('acquire');
      await sem.acquire();
      try {
        _message('  acquired');
        await Task.sleep();
      } finally {
        _message('release');
        await sem.release();
      }
    });

    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
task 0: acquire
task 0:   acquired
task 1: acquire
task 2: acquire
task 3: acquire
task 4: acquire
task 0: release
task 1:   acquired
task 1: release
task 2:   acquired
task 2: release
task 3:   acquired
task 3: release
task 4:   acquired
task 4: release

```

### Condition variable

A `ConditionVariable` is a synchronization primitive  that allows to wait for a particular condition to become `true` before proceeding.\
It is always used in conjunction with a locking to safely manage access to the shared data and prevent race conditions.

An example of using two condition variables in conjunction with a binary semaphore (as a synchronization mechanism):

[example/example_condition_variable.dart](https://github.com/mezoni/multitasking/blob/main/example/example_condition_variable.dart)

```dart
import 'dart:collection';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';
import 'package:multitasking/synchronization/condition_variable.dart';

Future<void> main(List<String> args) async {
  final lock = BinarySemaphore();
  final notEmpty = ConditionVariable(lock);
  final notFull = ConditionVariable(lock);
  const capacity = 4;
  final products = Queue<int>();
  var productId = 0;
  var produced = 0;
  var consumed = 0;
  const count = 3;

  final producer = Task.run(name: 'producer', () async {
    for (var i = 0; i < count; i++) {
      await Future<void>.delayed(Duration(milliseconds: 50));
      final product = productId++;
      produced++;
      _message('produced: $product');
      _message('lock.acquire()');
      await lock.acquire();
      _message('lock.acquired');
      try {
        while (products.length == capacity) {
          _message('notFull.wait()');
          await notFull.wait();
        }

        _message('added product: $product');
        products.add(product);
        _message('products: $products');
        _message('notEmpty.notifyAll()');
        await notEmpty.notifyAll();
      } finally {
        _message('lock.release()');
        await lock.release();
      }
    }
  });

  final consumer = Task.run(name: 'consumer', () async {
    for (var i = 0; i < count; i++) {
      int? product;
      _message('lock.acquire()');
      await lock.acquire();
      _message('lock.acquired');
      try {
        while (products.isEmpty) {
          _message('notEmpty.wait()');
          await notEmpty.wait();
        }

        product = products.removeFirst();
        _message('removed product: $product');
        _message('products: $products');
        _message('notFull.notifyAll()');
        await notFull.notifyAll();
      } finally {
        _message('lock.release()');
        await lock.release();
      }

      await Future<void>.delayed(Duration(milliseconds: 200));
      _message('consumed product: $product');
      consumed++;
    }
  });

  await Task.whenAll([consumer, producer]);

  _message('produced: $produced');
  _message('consumed: $consumed');
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
consumer: lock.acquire()
consumer: lock.acquired
consumer: notEmpty.wait()
producer: produced: 0
producer: lock.acquire()
producer: lock.acquired
producer: added product: 0
producer: products: {0}
producer: notEmpty.notifyAll()
producer: lock.release()
consumer: removed product: 0
consumer: products: {}
consumer: notFull.notifyAll()
consumer: lock.release()
producer: produced: 1
producer: lock.acquire()
producer: lock.acquired
producer: added product: 1
producer: products: {1}
producer: notEmpty.notifyAll()
producer: lock.release()
producer: produced: 2
producer: lock.acquire()
producer: lock.acquired
producer: added product: 2
producer: products: {1, 2}
producer: notEmpty.notifyAll()
producer: lock.release()
consumer: consumed product: 0
consumer: lock.acquire()
consumer: lock.acquired
consumer: removed product: 1
consumer: products: {2}
consumer: notFull.notifyAll()
consumer: lock.release()
consumer: consumed product: 1
consumer: lock.acquire()
consumer: lock.acquired
consumer: removed product: 2
consumer: products: {}
consumer: notFull.notifyAll()
consumer: lock.release()
consumer: consumed product: 2
main(): produced: 3
main(): consumed: 3

```

### Reentrant lock

A `ReentrantLock` is a synchronization primitive that works like a mutex.  
It blocks execution of all zones that do not own this lock.  
The zone that acquired the permit becomes the owner of this lock.  
The zone owner can enter and exit as long as it holds this lock.

An example of reentering a `ReentrantLock`:

[example/example_reentrant_lock.dart](https://github.com/mezoni/multitasking/blob/main/example/example_reentrant_lock.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/reentrant_lock.dart';

Future<void> main(List<String> args) async {
  final lock = ReentrantLock();
  var count = 0;

  Future<void> func(int i) async {
    await lock.acquire();
    try {
      await Future<void>.delayed(Duration(milliseconds: 50));
      count++;
      _message('Increment counter: $count');
      if (i + 1 < 3) {
        await func(i + 1);
      }
    } finally {
      await lock.release();
    }
  }

  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final t = Task.run(() => func(0));
    tasks.add(t);
  }

  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Task(0): Increment counter: 1
Task(0): Increment counter: 2
Task(0): Increment counter: 3
Task(1): Increment counter: 4
Task(1): Increment counter: 5
Task(1): Increment counter: 6
Task(2): Increment counter: 7
Task(2): Increment counter: 8
Task(2): Increment counter: 9

```

### Lock interface

A `Lock` is an interface that simplifies the use of `locking` primitives.  
For example, this interface is implemented by the classes `BinarySemaphore` and  `ReentrantLock`.  
These classes can be used for exclusive locking.  

An example of using a binary semaphore as a locking mechanism:

[example/example_lock.dart](https://github.com/mezoni/multitasking/blob/main/example/example_lock.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/binary_semaphore.dart';

Future<void> main(List<String> args) async {
  final sem = BinarySemaphore();
  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final task = Task.run(() async {
      await sem.lock(() async {
        _message('Enter');
        await Future<void>.delayed(Duration(milliseconds: 100));
        _message('Leave');
      });
    });

    tasks.add(task);
  }

  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Task(0): Enter
Task(0): Leave
Task(1): Enter
Task(1): Leave
Task(2): Enter
Task(2): Leave

```

### Multiple write single read object

A `MultipleWriteSingleReadObject`is a synchronized object.

If an object is not held by one or more `writers`, then `readers` can access the value of and object (using the [read] method) without any delay, having previously checked the state of the object by reading the value [isLocked].

If a object is held by one or more `writers`, then `readers` must waiting for the `write` operations to complete using the [wait] method.\
After that, a value can be accessed immediately using the [read] method.

If an object is held by one or more `readers` and a `write` operation is requested, the `writer` will wait  for all previous `read` and `write`
operations.

An example of reading and writing a shared object simultaneously:

[example/example_multiple_write_single_read_object.dart](https://github.com/mezoni/multitasking/blob/main/example/example_multiple_write_single_read_object.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/multiple_write_single_read_object.dart';

Future<void> main(List<String> args) async {
  final object = MultipleWriteSingleReadObject(0);
  final tasks = <AnyTask>[];

  void scheduleTask(int ms, Future<void> Function() action) {
    final t = Task.run<void>(() async {
      await Task.sleep(ms);
      await action();
    });
    tasks.add(t);
  }

  void scheduleRead(int ms) {
    scheduleTask(ms, () async {
      var isLocked = false;
      if (object.isLocked) {
        isLocked = true;
        _message('wait read');
        await object.wait();
      }

      final v = object.read();
      final mode = isLocked ? 'read (after wait)' : 'read';
      _message('$mode $v');
    });
  }

  void scheduleWrite(int ms) {
    scheduleTask(ms, () async {
      _message('wait write');
      await object.write((value) async {
        await Future<void>.delayed(Duration(milliseconds: 100));
        final v = ++value;
        _message('write $v');
        return v;
      });
    });
  }

  scheduleRead(0);
  scheduleWrite(0);
  scheduleWrite(0);
  scheduleRead(0);
  scheduleRead(200);
  scheduleRead(400);

  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Task(0): read 0
Task(1): wait write
Task(2): wait write
Task(3): wait read
Task(1): write 1
Task(4): wait read
Task(2): write 2
Task(3): read (after wait) 2
Task(4): read (after wait) 2
Task(5): read 2

```

### Manual reset event

A `ManualResetEvent` is a synchronization primitive that is used to manage signaling.  
When an event is in a `signaled` state, any calls to the `wait()` method will not block execution of the calling code.  
When an event is in a `non-signaled` state, any calls to the `wait()` method will block execution of the calling code.

Once switched to the `signaled` state, the event remains in the `signaled` state until it is manually `reset()`.

An example of using a manual reset event to start tasks simultaneously.

[example/example_manual_reset_event.dart](https://github.com/mezoni/multitasking/blob/main/example/example_manual_reset_event.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/reset_events.dart';

Future<void> main(List<String> args) async {
  final mre = ManualResetEvent(false);
  final sw = Stopwatch();
  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final task = Task.run(() async {
      await mre.wait();
      _message('${sw.elapsedMilliseconds}');
    });

    tasks.add(task);
  }

  const ms = 500;
  sw.start();
  _message('${sw.elapsedMilliseconds}');
  _message('Waiting $ms ms');
  await Future<void>.delayed(Duration(milliseconds: ms));
  _message('Start');
  await mre.set();
  await Task.whenAll(tasks);
}

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
main(): 0
main(): Waiting 500 ms
main(): Start
Task(0): 517
Task(1): 519
Task(2): 519

```
