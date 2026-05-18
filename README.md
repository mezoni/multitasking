# Multitasking

Cooperative multitasking using asynchronous tasks and synchronization primitives, with the ability to safely cancel groups of nested tasks performing I/O wait or listen operations.

Version: 7.10.0

[![Pub Package](https://img.shields.io/pub/v/multitasking.svg)](https://pub.dev/packages/multitasking)
[![Pub Monthly Downloads](https://img.shields.io/pub/dm/multitasking.svg)](https://pub.dev/packages/multitasking/score)
[![GitHub Issues](https://img.shields.io/github/issues/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/issues)
[![GitHub Forks](https://img.shields.io/github/forks/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/forks)
[![GitHub Stars](https://img.shields.io/github/stars/mezoni/multitasking.svg)](https://github.com/mezoni/multitasking/stargazers)
[![GitHub License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://raw.githubusercontent.com/mezoni/multitasking/main/LICENSE)

![Producer/consumer problem: Monitor and 2 condition variables operation](https://i.imgur.com/gkMEGId.gif)

Producer/consumer problem: Monitor and 2 condition variables operation.

![example_task_download_file.dart](https://i.imgur.com/IBny2xe.gif)

[Example of a file download task.](https://github.com/mezoni/multitasking/blob/main/example/example_task_download_file.dart)

Table of Contents:

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
    - [Tasks can be awaited in different ways](#tasks-can-be-awaited-in-different-ways)
    - [Tasks can be awaited as a stream](#tasks-can-be-awaited-as-a-stream)
    - [Tasks can be awaited in the order of queue](#tasks-can-be-awaited-in-the-order-of-queue)
    - [The task can be canceled using a cancellation token](#the-task-can-be-canceled-using-a-cancellation-token)
    - [The task can be canceled during `Task.delay()`](#the-task-can-be-canceled-during-taskdelay)
    - [The task can be canceled as a group of tasks](#the-task-can-be-canceled-as-a-group-of-tasks)
    - [The task can be canceled using inherited token](#the-task-can-be-canceled-using-inherited-token)
    - [The task can be canceled while listening to the stream](#the-task-can-be-canceled-while-listening-to-the-stream)
    - [The group of tasks can be safely canceled while working with the network](#the-group-of-tasks-can-be-safely-canceled-while-working-with-the-network)
    - [The tasks can be safely canceled during long running network operation](#the-tasks-can-be-safely-canceled-during-long-running-network-operation)
    - [The waiting for a non-cancelable task can be canceled](#the-waiting-for-a-non-cancelable-task-can-be-canceled)
    - [Tasks can be paused and resumed](#tasks-can-be-paused-and-resumed)
    - [A stream can be transformed to handle termination events](#a-stream-can-be-transformed-to-handle-termination-events)
    - [A stream can be transformed to handle completion status](#a-stream-can-be-transformed-to-handle-completion-status)
    - [A stream subscription can be paused and resumed using a token](#a-stream-subscription-can-be-paused-and-resumed-using-a-token)
    - [A stream subscription can be cancelled using a non-blocking cancellation](#a-stream-subscription-can-be-cancelled-using-a-non-blocking-cancellation)
    - [A stream with cancellation token support can be created using the `async*` generator](#a-stream-with-cancellation-token-support-can-be-created-using-the-async-generator)
    - [A stream subscription can be canceled on `timeout`](#a-stream-subscription-can-be-canceled-on-timeout)
    - [A stream subscription can process data longer than the timeout](#a-stream-subscription-can-process-data-longer-than-the-timeout)
    - [The work performed in 'Isolate' can be terminated in different ways](#the-work-performed-in-isolate-can-be-terminated-in-different-ways)
    - [The work performed in 'Zone' can be terminated in different ways](#the-work-performed-in-zone-can-be-terminated-in-different-ways)
    - [The work can be executed on different platforms](#the-work-can-be-executed-on-different-platforms)
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
- [Completer](https://api.dart.dev/dart-async/Completer-class.html)
- [Future](https://api.dart.dev/dart-async/Future-class.html)
- [Finalizer](https://api.dart.dev/dart-core/Finalizer-class.html)

Are the tasks safe and reliable?  
Yes, because the tasks have a very simple construction and operating mechanism.  
In a few words, the task life cycle can be described as follows:

- A task is created with an action in the form of a function callback that must be executed
- The initial state of a task is the state in which the action has not yet started to execute
- After receiving a command to start executing an action, the task waits for the function callback  (`action`) to complete its execution
- After completing this `action`, the task (using `Completer<T>`) puts itself into one of the states indicating the completion of the task
- After this, the task result (or error) becomes available through several public and private members (`result`, `exception`, `_future`)

To simplify working with the task, it itself is an instance of an object that implements the `Future` interface.  
In this case, the task does not replace `Future<T>` (doesn't reinvent the wheel), it uses the standard `Completer<T>` and its field `future`.  

Thus, a `Task<T>` is an object that implements the `Future<T>`  interface by using `Completer<T>`.  
This task only adds the ability (to `Future<T>`) to start its execution on demand (`run`, `start`) and track the completion state of the `action`.

The main purpose of tasks is to conveniently manage a large number of asynchronous tasks with nested subtasks running simultaneously and cooperatively, with the ability to perform their soft, controlled, and broadly functional stop (cancellation), and the ability to write a task destructor in the body of the task itself.  
In this way, a request to cancel tasks (and all nested subtasks and all internal critically important operations) can be handled in such a way that everything happens harmoniously and completely safely.  
A cancellation request is made using a special token. A task cancellation token can be used synchronously or asynchronously (via a subscription, which attaches a handler only for the duration of a critical and potentially very long operation).

Below is a complete list of features implemented in this package:

**Multitasking:**

- Aggregate error
- Cancellation exception
- Cancellation token
- Cancellation token source
- Task
- Task completion source
- Task state error

**Streams:**

- Cancelable stream factory
- Cancellation transformer
- Pause transformer

**Work:**

- Work
- Isolated work
- Zoned work

**Synchronization primitives:**

- Auto reset event
- Binary semaphore
- Condition variable
- Counting semaphore
- Lock
- Manual reset event
- Multiple write single read object
- Reentrant lock
- Progress

**Miscellaneous:**

- Countdown timer
- Pause token
- Pause token source
- Progress
- Speed meter

## Practical use

Tasks are very lightweight objects. The actions performed by tasks are not much slower than those performed by futures.

A `Task` is an object representing some operation that will complete in the future.\
Tasks are executed asynchronously and cooperatively.\
Cooperative multitasking is a concurrency model where tasks voluntarily yield control (using `await`).

The result of a task execution is the result of computing the value of the task action. It can be either a value or an error.\
The task itself is an object of `Future` that wraps the result of the computation.\
The main difference between the task and the `Future` is as follows:

- Task can be created in unstarted state and can be started by demand
- If the task execution fails, the exception will not be propagated immediately
- For a task, it is possible to track the current state through the `status` property or through the `is{Status}` property (for example, `isRunning`)

### The task does not begin executing the computation immediately after it is created

The task supports delayed start. Or it may never even be started.\
After the computation is completed, the task captures the result of the computation.

### In case of completion with an exception, the task does not propagate this exception to the unhandled exception handler immediately

This unobserved exception is stored in the relevant task object instance until the task is aware that an exception has been observed.\
If the task isn not aware that an exception was observed, this exception will be propagated in the task finalizer (`Finalizer`).\
If the finalizer is not executed by runtime (due to Dart SDK limitations), the exception will remain unobserved.\
For this reason, due to the limited functionality of the finalizer, it is recommended to always observe task exceptions (detecting, catching, handling).

Exceptions in task can be observed in one of the following ways:

- `await task`
- `task.result` (only after the task is terminated)
- `task.exception` (only after the task is terminated)
- `task.asStream()` (inherited from `Future`)
- `task.catchError()` (inherited from `Future`)
- `task.then()` (inherited from `Future`)
- `task.timeout()` (inherited from `Future`)
- `task.whenComplete()` (inherited from `Future`)

## Examples of the main features of the `Task`

Task have features that extend, complement, or modify the functionality of futures.

Remark: All examples below were run during the creation of this document and contain actual output to the standard output streams (stdout and stderr).

### The task do not throw exceptions at the completion point in case of unsuccessful completion

Example with `Future`:

[example/example_future.dart](https://github.com/mezoni/multitasking/blob/main/example/example_future.dart)

```dart
import 'dart:async';

Future<void> main() async {
  final task = Future<int>(() => throw Exception('Error'));

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
Exception: Error
#0      main.<anonymous closure> (file:///home/andrew/prj/multitasking/example/example_future.dart:4:34)
#1      new Future.<anonymous closure> (dart:async/future.dart:260:40)
#2      Timer._createTimer.<anonymous closure> (dart:async-patch/timer_patch.dart:18:15)
#3      _Timer._runTimers (dart:isolate-patch/timer_impl.dart:423:19)
#4      _Timer._handleMessage (dart:isolate-patch/timer_impl.dart:454:5)
#5      _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:192:12)

```

The same example with task:

[example/example_task_await.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_await.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = Task.run<int>(() => throw Exception('Error'));

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
Exception: Error

```

A failed (or canceled) task does not affect the execution of other code (`Do some work`) if the task object instance is referenced.  
The task will not throw an exception until it is `awaited` in some way (e.g. `tasks.then()`, `await task`, etc.).

If the executing code do not `await` the task and there are no references to the task object instance, an exception will be thrown during garbage collection when the task is finalized.  
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
    _message('Started');
    Object? handle;

    Task.onExit((task) {
      _message("Exit with status '${task.status.name}'");
      if (handle != null) {
        _message("Frees up 'handle'");
      }
    });

    handle = Object();
    throw Exception('Error in ${Task.current}');
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

void _message(String text) {
  final task = Task.current.name ?? '${Task.current}';
  print('$task: $text');
}

```

Output:

```txt
Task(1): Started
Task(1): Exit with status 'failed'
Task(1): Frees up 'handle'
Do some work
Work completed
Exception: Error in Task(1)

```

### The task immediately propagates an exception if it is an unhandled exception

An unhandled exception is considered to be an exception (except `CancellationException`) that occurs after a task has completed.  
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
        throw Exception('Error on exit');
      });

      Timer(const Duration(), () {
        throw Exception('Error in timer');
      });
      throw Exception('Error in body');
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
Unhandled error: Exception: Error on exit
Task error: Exception: Error in body
Unhandled error: Exception: Error in timer

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

### Tasks can be awaited in different ways

Example of awaiting the tasks in different ways:

[example/example_task_await_in_different_ways.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_await_in_different_ways.dart)

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
  print('First task: ${firstTask.toString()} (${firstTask.status.name})');
  try {
    final result = await firstTask;
    print('First result: $result');
  } catch (e) {
    print('Error: $e');
  }

  print('Tasks:');
  print(tasks.map((e) {
    return '${e.toString()} (${e.status.name})';
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
    var s = '${task.toString()}: ${task.status.name}';
    if (task.isSucceeded) {
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
First task: Task(1) (failed)
Error: Bad state: Some error
Tasks:
Task(1) (failed), Task(3) (running), Task(4) (running)
whenAll()
Ready: 66.67%
Ready: 100.00%
Error: AggregateError: One or more errors occurred. (Bad state: Some error)
Task(1): failed, exception: Bad state: Some error
Task(3): succeeded, result: 1
Task(4): succeeded, result: 2

```

### Tasks can be awaited as a stream

Example of awaiting the tasks as a stream

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
    print('${task.toString()} ${task.status.name}');
    if (task.isSucceeded) {
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
Task(1) failed
Task(3) succeeded
Task(3) result 1
Task(4) succeeded
Task(4) result 2

```

### Tasks can be awaited in the order of queue

Example of awaiting the tasks in the order of queue

[example/example_task_await_in_order_of_queue.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_await_in_order_of_queue.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  // Text and time to complete a task
  final events = [
    ('A', 200),
    ('B', 100),
    ('C', 200),
    ('D', 100),
    ('E', 200),
    ('F', 100),
    ('G', 200),
    ('H', 100),
  ];

  final controller = StreamController<Task<String>>();
  unawaited(() async {
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final text = event.$1;
      final ms = event.$2;
      final Task<String> task;
      if (i == 2) {
        task = Task.run(() {
          throw Exception('Some error on $text');
        });
      } else {
        task = Task.run(() async {
          await Future<void>.delayed(Duration(milliseconds: ms));
          print('$text Ready');
          return text;
        });
      }

      controller.add(task);
      // Emulates a small interval between the receipt of tasks.
      await Future<void>.delayed(Duration(milliseconds: 75));
    }

    print('No more tasks');
    await controller.close();
  }());

  unawaited(() async {
    final stream = controller.stream;
    await for (final task in stream) {
      try {
        await task;
        print(task.result);
        // Do something with the result.
        await Future<void>.delayed(Duration(milliseconds: 200));
      } catch (e) {
        print(e);
      }
    }

    print("The end");
  }());

  print("Let's start");
}

```

Output:

```txt
Let's start
B Ready
A Ready
A
D Ready
B
F Ready
E Ready
Exception: Some error on C
D
No more tasks
H Ready
G Ready
E
F
G
H
The end

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
  throw CancellationException();
}
```

### The task can be canceled during `Task.delay()`

All that is required for this is to pass the token as an argument to method `Task.delay()`.

Example of cancelling a task during task sleep`Task.delay()`:

[example/example_task_cancel_during_delay.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_during_delay.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource();
  final token = cts.token;

  var count = 0;
  final task = Task.run(() async {
    token.throwIfCanceled();
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
CancellationException
main(): count: 239366

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
    if (!task.isSucceeded) {
      cts.cancel();
    }
  }

  parent = Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: ${task.toString()} (${task.status.name})');
      onExit(task);
    });

    token.throwIfCanceled();
    for (var i = 1; i <= 3; i++) {
      final t = Task<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: ${task.toString()} (${task.status.name})');
          onExit(task);
        });

        token.throwIfCanceled();
        final n = i;
        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;
          await Task.delay(500, token);
          if (n == 1) {
            throw Exception('Failure in ${Task.current}');
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
Task('Child 1', 3) works: 0 of 4
Task('Child 2', 4) works: 0 of 4
Task('Child 3', 5) works: 0 of 4
On exit: Task('Child 1', 3) (failed)
On exit: Task('Child 2', 4) (canceled)
On exit: Task('Child 3', 5) (canceled)
On exit: Task('Parent', 1) (failed)
AggregateError: One or more errors occurred. (Exception: Failure in Task('Child 1', 3)) (CancellationException) (CancellationException)

```

### The task can be canceled using inherited token

Example of canceling a tasks using inherited token:

[example/example_task_cancel_using_inherited_token.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_using_inherited_token.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts1 = CancellationTokenSource();
  Timer(Duration(milliseconds: 100), () {
    print('cts.cancel()');
    cts1.cancel();
  });

  final task = Task.run(token: cts1.token, () async {
    final tasks = <AnyTask>[];
    for (var i = 0; i < 5; i++) {
      final task = Task.run(_doWork);
      tasks.add(task);
    }

    await Task.whenAll(tasks);
  });

  try {
    await task;
  } catch (e) {
    _message('Error: $e');
  }
}

Future<void> _doWork() async {
  _message('Begin work');
  final token = Task.token;
  try {
    for (var i = 0; i < 10; i++) {
      token.throwIfCanceled();
      for (var j = 0; j < 10; j++) {
        await Future<void>.delayed(Duration(milliseconds: 10));
      }
    }
  } catch (e) {
    _message('Error: $e');
    rethrow;
  }

  _message('End work');
}

void _message(Object object) {
  print('${Task.current} $object');
}

```

Output:

```txt
Task(3) Begin work
Task(4) Begin work
Task(5) Begin work
Task(6) Begin work
Task(7) Begin work
cts.cancel()
Task(3) Error: CancellationException
Task(4) Error: CancellationException
Task(5) Error: CancellationException
Task(6) Error: CancellationException
Task(7) Error: CancellationException
Task('main()', 0) Error: CancellationException

```

### The task can be canceled while listening to the stream

Example of canceling the emulation of the `await for` statement using `ForEach` class:

[example/example_task_cancel_during_stream_iteration.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_during_stream_iteration.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
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
    final task = _doWork(stream, token, isFirst: i == 0);
    tasks.add(task);
  }

  try {
    await Task.whenAll(tasks);
  } catch (e) {
    print(e);
  }

  for (final task in tasks) {
    if (task.isSucceeded) {
      final result = await task;
      _message('Result of ${task.toString()}: $result');
    }
  }
}

Task<int> _doWork(
  Stream<int> stream,
  CancellationToken token, {
  bool isFirst = false,
}) {
  return Task.run(() async {
    token.throwIfCanceled();
    final list = <int>[];
    await for (final event in stream.asCancelable(token)) {
      _message('Received event: $event');
      list.add(event);
      if (isFirst && list.length == 1) {
        _message('I want to break free...');
        break;
      }
    }

    await Task.sleep();
    _message('Processing data: $list');
    if (isFirst) {
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
Task(1): Received event: 0
Task(1): I want to break free...
Task(3): Received event: 0
Task(4): Received event: 0
Task(1): Processing data: [0]
Send event: 1
Task(3): Received event: 1
Task(4): Received event: 1
Send event: 2
Task(3): Received event: 2
Task(4): Received event: 2
main(): Cancellation requested
CancellationException
main(): Result of Task(1): 1
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
      token.throwIfCanceled();
      _message('Fetching feed: $uri');
      final request = Request('GET', uri);
      final task = Task.run(() => Client().send(request));
      StreamedResponse response;
      try {
        response = await task.withCancellation(token);
      } on CancellationException {
        unawaited(() async {
          try {
            await (await task).stream.listen((_) {}).cancel();
          } catch (e) {/**/}
        }());

        rethrow;
      }

      final stream = response.stream;
      await for (final event in stream.asCancelable(token)) {
        bytes.addAll(event);
      }

      final statusCode = response.statusCode;
      if (statusCode != 200) {
        throw Exception('Http error ($statusCode)');
      }

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
    print('${task.toString()}: ${task.status.name}');
    if (task.isSucceeded) {
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
Task(1): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml
Task(6): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Science.xml
Task(10): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Movies.xml
Task(14): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Europe.xml
Task(18): Fetching feed: https://rss.nytimes.com/services/xml/rss/nyt/Music.xml
Task(1): Processing feed: https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml
main(): Canceling
CancellationException
----------------------------------------
Task(1): succeeded
Data <?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/element
----------------------------------------
Task(6): canceled
No data
----------------------------------------
Task(10): canceled
No data
----------------------------------------
Task(14): canceled
No data
----------------------------------------
Task(18): canceled
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
    if (task.isSucceeded) {
      final filename = await task;
      print('Done: $filename');
    }
  }
}

Task<String> _download(Uri uri, String filename, CancellationToken token) {
  return Task.run(() async {
    var bytes = 0;

    Task.onExit((task) {
      print('${task.toString()}: ${task.status.name}');
      _message('Downloaded: $bytes');
    });

    token.throwIfCanceled();
    final request = Request('GET', uri);
    final task = Task.run(() => Client().send(request));
    StreamedResponse response;
    try {
      response = await task.withCancellation(token);
    } on CancellationException {
      unawaited(() async {
        try {
          await (await task).stream.listen((_) {}).cancel();
        } catch (e) {/**/}
      }());

      rethrow;
    }

    final stream = response.stream;
    await for (final event in stream.asCancelable(token)) {
      // Simulating the addition of bytes
      bytes += event.length;
    }

    final statusCode = response.statusCode;
    if (statusCode != 200) {
      throw Exception('Http error ($statusCode)');
    }

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
Task(6): canceled
Task(6): Downloaded: 3481599
Task(1): canceled
Task(1): Downloaded: 2457598
CancellationException

```

### The waiting for a non-cancelable task can be canceled

An example of canceling the wait for a non-cancelable task:

[example/example_task_cancel_waiting_for_non_cancelable_action.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_cancel_waiting_for_non_cancelable_action.dart)

```dart
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final cts = CancellationTokenSource(Duration(seconds: 1));
  final task = _longTask();
  try {
    final result = await task.withCancellation(cts.token);
    print('Result: $result');
  } on CancellationException {
    print('CancellationException');
    if (!task.isTerminated) {
      print('Task still running');
    }
  }

  print('Begin next work');
}

Task<int> _longTask() {
  return Task.run(() async {
    await Future<void>.delayed(Duration(seconds: 2));
    print('Task terminated');
    return 10;
  });
}

```

Output:

```txt
CancellationException
Task still running
Begin next work
Task terminated

```

### Tasks can be paused and resumed

Example of pausing and resuming the task

[example/example_task_pause.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_pause.dart)

```dart
import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final pts = PauseTokenSource();
  final pause = pts.token;

  _watch.start();
  Timer(Duration(milliseconds: 50), () async {
    _message('pause');
    await pts.pause();
  });

  Timer(Duration(milliseconds: 500), () async {
    _message('resume');
    await pts.resume();
  });

  final list = await _doWork(pause);
  print(list);
}

final _watch = Stopwatch();

Task<List<int>> _doWork(PauseToken pause) {
  return Task.run(() async {
    final list = <int>[];
    for (var i = 0; i < 3; i++) {
      _message(i);
      list.add(i);
      // Simulate some work
      await Task.delay(100);
      await pause.wait();
    }

    return list;
  });
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
20: 0
56: pause
507: resume
509: 1
611: 2
[0, 1, 2]

```

### A stream can be transformed to handle termination events

Example of handling a stream termination events:

[example/example_stream_handle_termination.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_handle_termination.dart)

```dart
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

```

Output:

```txt
----------------------------------------
Handle cancel
----------------------------------------
1
2
break
onCancel
onTerminate
----------------------------------------
Handle done
----------------------------------------
1
2
3
onDone
onTerminate
----------------------------------------
Handle error
----------------------------------------
1
2
throw Exception()
onError
onTerminate

```

### A stream can be transformed to handle completion status

Example of waiting for a stream to complete:

[example/example_stream_handle_completion.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_handle_completion.dart)

```dart
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

      print('throw "Exception" in numbers');
      throw Exception('Error in numbers');
    }

    final s1 = Stream.fromIterable(numbers());
    final completion = StreamCompletion();
    final s2 = s1.withCompletion(completion);

    s2.listen(
      print,
      onError: (e) {},
      cancelOnError: true,
    );

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

```

Output:

```txt
----------------------------------------
Handle cancel
----------------------------------------
1
2
break
Status: canceled
----------------------------------------
Handle done
----------------------------------------
1
2
3
Status: done
----------------------------------------
Handle error
----------------------------------------
1
2
throw "Exception" in numbers
Status: error
Error: Exception: Error in numbers

```

### A stream subscription can be paused and resumed using a token

Example of pausing and resuming a stream subscription using a token:

[example/example_stream_pause_subscription.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_pause_subscription.dart)

```dart
import 'dart:async';

import 'package:multitasking/misc/pause.dart';
import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  Stream<int> gen() async* {
    for (var i = 0; i < 10; i++) {
      _message('Yield: $i');
      yield i;
      await Task.delay(100);
    }

    _message('Generation complete');
  }

  final pts = PauseTokenSource();
  final cts = CancellationTokenSource();
  _watch.start();
  Timer(Duration(milliseconds: 50), () async {
    _message('Pause');
    await pts.pause();
  });

  Timer(Duration(milliseconds: 500), () async {
    _message('Resume');
    await pts.resume();
  });

  Timer(Duration(milliseconds: 650), () async {
    _message('Cancel');
    cts.cancel();
  });

  final stream = gen().asCancelable(cts.token, pauseToken: pts.token);
  try {
    await for (final event in stream) {
      _message('Event: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }
}

final _watch = Stopwatch();

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
18: Yield: 0
22: Event: 0
54: Pause
126: Yield: 1
504: Resume
506: Event: 1
609: Yield: 2
609: Event: 2
655: Cancel
711: Yield: 3
713: Error: CancellationException

```

### A stream subscription can be cancelled using a non-blocking cancellation

Example of canceling a stream subscription using a non-blocking cancellation:

[example/example_stream_non_blocking_cancellation.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_non_blocking_cancellation.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  for (final blockOnCancel in [true, false]) {
    print('-' * 40);
    print('${blockOnCancel ? 'Blocking' : 'Non-blocking'} cancellation ');
    print('-' * 40);
    _watch.reset();
    _watch.start();
    final cts = CancellationTokenSource();
    Timer(Duration(milliseconds: 200), () {
      _message('Canceling');
      cts.cancel();
    });

    final stream =
        _generate().asCancelable(cts.token, blockOnCancel: blockOnCancel);
    try {
      await for (final event in stream) {
        _message('Received: $event');
      }
    } catch (e) {
      _message('catch(e): $e');
    }

    _message('Begin next work');
    await Future<void>.delayed(Duration(milliseconds: 50));
    _message('End next work');
  }
}

final _watch = Stopwatch();

Future<int> _compute(int value) async {
  _message('Computing');
  await Task.delay(150);
  if (value == 1) {
    _message('Error computing');
    throw Exception('Error');
  } else {
    _message('Computed: $value');
  }

  return value;
}

Stream<int> _generate() async* {
  for (var i = 0; i < 10; i++) {
    yield await _compute(i);
    _message('After yield: $i');
  }

  _message('Generation complete');
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
----------------------------------------
Blocking cancellation 
----------------------------------------
24: Computing
183: Computed: 0
186: Received: 0
186: After yield: 0
187: Computing
204: Canceling
338: Error computing
341: catch(e): CancellationException
341: Begin next work
394: End next work
----------------------------------------
Non-blocking cancellation 
----------------------------------------
0: Computing
151: Computed: 0
152: Received: 0
152: After yield: 0
152: Computing
201: Canceling
202: catch(e): CancellationException
202: Begin next work
254: End next work
304: Error computing

```

### A stream with cancellation token support can be created using the `async*` generator

Example of creating a stream with cancellation token support using the `async*` generator:

[example/example_stream_with_cancellation_token_from_generator.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_with_cancellation_token_from_generator.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  Stream<int> streamFromGenerator(CancellationToken token) async* {
    _message('Before yield: 1');
    yield 1;
    _message('After yield: 1');
    // await Task.delay(4000, token);
    await _doWork(token);
    yield 2;
  }

  _header("Cancel with 'CancellationTokenSource'");
  final cts = CancellationTokenSource();
  Timer(Duration(seconds: 2), cts.cancel);
  final stream1 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.start();
  try {
    await for (final event in stream1.asCancelable(cts.token)) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _header("Cancel with 'StreamSubscription.cancel()'");
  final stream2 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.reset();
  _watch.start();
  final subscription = stream2.listen(
    (event) {
      _message('Received: $event');
    },
    onError: (Object e) {
      _message('Error: $e');
    },
  );

  Timer(Duration(seconds: 2), () async {
    try {
      await subscription.cancel();
    } catch (e) {
      _message('Error: $e');
    }
  });
}

final _watch = Stopwatch();

Future<void> _doWork(CancellationToken token) async {
  const x = 10;
  const y = 10;
  const z = 40;
  const executionTime = x * y * z;
  _message('Begin work (about $executionTime ms)');
  try {
    for (var i = 0; i < x; i++) {
      for (var j = 0; j < y; j++) {
        token.throwIfCanceled();
        await Future<void>.delayed(Duration(milliseconds: z));
      }
    }
  } on CancellationException {
    _message('Work canceled');
    rethrow;
  }

  _message('End work');
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
----------------------------------------
Cancel with 'CancellationTokenSource'
----------------------------------------
14: Before yield: 1
18: Received: 1
19: After yield: 1
19: Begin work (about 4000 ms)
2025: Work canceled
2030: Error: CancellationException
----------------------------------------
Cancel with 'StreamSubscription.cancel()'
----------------------------------------
0: Before yield: 1
0: Received: 1
0: After yield: 1
0: Begin work (about 4000 ms)
2002: Work canceled
2002: Error: CancellationException

```

### A stream subscription can be canceled on `timeout`

Example of canceling a stream subscription on `timeout`

[example/example_stream_cancel_on_timeout.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_cancel_on_timeout.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  Stream<int> streamFromGenerator(CancellationToken token) async* {
    _message('Before yield: 1');
    yield 1;
    _message('After yield: 1');
    // await Task.delay(4000, token);
    await _doWork(token);
    yield 2;
  }

  _header('Cancelling a cancellable stream');
  final cts1 = CancellationTokenSource();
  final stream1 = CancelableStreamFactory.fromGenerator(streamFromGenerator);
  _watch.start();
  try {
    await for (final event
        in stream1.asCancelable(cts1.token, timeout: Duration(seconds: 2))) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _message('End');

  _header('Cancelling a non-cancellable stream');
  final cts2 = CancellationTokenSource();
  final stream2 = streamFromGenerator(cts2.token);
  _watch.start();
  try {
    await for (final event in stream2.asCancelable(
      cts1.token,
      blockOnCancel: false,
      timeout: Duration(seconds: 2),
    )) {
      _message('Received: $event');
    }
  } catch (e) {
    _message('Error: $e');
  }

  _message('End');
}

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

final _watch = Stopwatch();

Future<void> _doWork(CancellationToken token) async {
  const x = 10;
  const y = 10;
  const z = 40;
  const executionTime = x * y * z;
  _message('Begin work (about $executionTime ms)');
  try {
    for (var i = 0; i < x; i++) {
      for (var j = 0; j < y; j++) {
        token.throwIfCanceled();
        await Future<void>.delayed(Duration(milliseconds: z));
      }
    }
  } on CancellationException {
    _message('Work canceled');
    rethrow;
  }

  _message('End work');
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
----------------------------------------
Cancelling a cancellable stream
----------------------------------------
21: Before yield: 1
28: Received: 1
29: After yield: 1
30: Begin work (about 4000 ms)
2052: Work canceled
2055: Error: TimeoutException
2055: End
----------------------------------------
Cancelling a non-cancellable stream
----------------------------------------
2056: Before yield: 1
2056: Received: 1
2057: After yield: 1
2057: Begin work (about 4000 ms)
4058: Error: TimeoutException
4058: End
6302: End work

```

### A stream subscription can process data longer than the timeout

Example of data processing longer than the timeout:

[example/example_stream_timeout_compatibility_with_await_for.dart](https://github.com/mezoni/multitasking/blob/main/example/example_stream_timeout_compatibility_with_await_for.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  const interval = 50;
  const timeout = interval * 3;

  Stream<int> gen(CancellationToken token) async* {
    for (var i = 0; i < 2; i++) {
      _message('Begin work');
      final int delay;
      if (i == 0) {
        delay = interval;
      } else {
        _message('Oh, long work...');
        delay = timeout * 5;
      }

      try {
        // For demonstration purposes only.
        // The token must be used for real purposes.
        await Task.delay(delay, token);
      } catch (e) {
        _message('Gen error: $e');
        rethrow;
      }

      _message('Work complete: $i');
      yield i;
      _message('After sent: $i');
    }
  }

  for (final basicFunctionality in [true, false]) {
    _header('Basic functionality: $basicFunctionality');

    // Not used for `timeout` demonstration purpose.
    // Manual cancellation will not be applied.
    final cts = CancellationTokenSource();

    var stream = gen(cts.token);
    if (!basicFunctionality) {
      stream = CancelableStreamFactory.fromGenerator(gen);
    }

    stream = stream.asCancelable(
      cts.token,
      blockOnCancel: false,
      timeout: Duration(milliseconds: timeout),
    );

    _watch.reset();
    _watch.start();
    try {
      await for (final event in stream) {
        _message('Enter await $event');
        // Performing the work longer than the timeout
        await Future<void>.delayed(const Duration(milliseconds: timeout * 2));
        _message('Exit await $event');
      }
    } catch (e) {
      _message('Error: $e');
    }

    _message('Begin new work');

    /// Waiting for example to terminate
    await Task.delay(3000);
  }
}

final _watch = Stopwatch();

void _header(String text) {
  print('-' * 40);
  print(text);
  print('-' * 40);
}

void _message(Object object) {
  print('${_watch.elapsedMilliseconds}: $object');
}

```

Output:

```txt
----------------------------------------
Basic functionality: true
----------------------------------------
10: Begin work
68: Work complete: 0
70: Enter await 0
373: Exit await 0
374: After sent: 0
374: Begin work
374: Oh, long work...
531: Error: TimeoutException
531: Begin new work
1129: Work complete: 1
----------------------------------------
Basic functionality: false
----------------------------------------
0: Begin work
53: Work complete: 0
53: Enter await 0
355: Exit await 0
355: After sent: 0
355: Begin work
355: Oh, long work...
511: Error: TimeoutException
511: Begin new work
511: Gen error: CancellationException

```

### The work performed in 'Isolate' can be terminated in different ways

An example of the different ways to terminated work performed in `Isolate`:

[example/example_isolated_work_terminate_in_different_ways.dart](https://github.com/mezoni/multitasking/blob/main/example/example_isolated_work_terminate_in_different_ways.dart)

```dart
import 'dart:async';
import 'dart:isolate';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/isolated_work.dart';

Future<void> main(List<String> args) async {
  _header('Terminate (force = true)');
  final work1 = IsolatedWork(_computeSync);
  Timer(Duration(milliseconds: 100), () => work1.terminate(force: true));
  try {
    await work1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate (force = false)');
  final work2 = IsolatedWork(_computeAsync);
  Timer(Duration(milliseconds: 100), work2.terminate);
  try {
    await work2.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final work3 = IsolatedWork(_computeWithToken, token: cts.token);
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await work3.run();
  } catch (e) {
    print('Error: $e');
  }
}

Future<int> _computeAsync() async {
  _message('Start');
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
  }
}

void _computeSync() {
  _message('Start');
  while (true) {}
}

Future<int> _computeWithToken() async {
  _message('Start');
  final token = Task.token;
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
    token.throwIfCanceled();
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
}

void _message(Object object) {
  print('Isolate(${Isolate.current.hashCode}): $object');
}

```

Output:

```txt
----------------------------------------
Terminate (force = true)
Isolate(602957086): Start
Error: CancellationException
----------------------------------------
Terminate (force = false)
Isolate(402132327): Start
Error: CancellationException
----------------------------------------
Terminate using a cancellation token
Isolate(877891537): Start
Error: CancellationException

```

### The work performed in 'Zone' can be terminated in different ways

An example of the different ways to terminated work performed in `Zone`:

[example/example_zoned_work_terminate_in_different_ways.dart](https://github.com/mezoni/multitasking/blob/main/example/example_zoned_work_terminate_in_different_ways.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/zoned_work.dart';

Future<void> main(List<String> args) async {
  _header('Terminate (force = false)');
  final work1 = ZonedWork(_computeAsync);
  Timer(Duration(milliseconds: 100), work1.terminate);
  try {
    await work1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final work2 = ZonedWork(_computeWithToken, token: cts.token);
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await work2.run();
  } catch (e) {
    print('Error: $e');
  }
}

Future<int> _computeAsync() async {
  _message('Start');
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
  }
}

Future<int> _computeWithToken() async {
  _message('Start');
  final token = Task.token;
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
    token.throwIfCanceled();
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
}

void _message(Object object) {
  print('Zone(${Zone.current.hashCode}): $object');
}

```

Output:

```txt
----------------------------------------
Terminate (force = false)
Zone(815676019): Start
Error: CancellationException
----------------------------------------
Terminate using a cancellation token
Zone(253288087): Start
Error: CancellationException

```

### The work can be executed on different platforms

An example of executing the work on different platforms:

[example/example_work_executing_on_different_platforms.dart](https://github.com/mezoni/multitasking/blob/main/example/example_work_executing_on_different_platforms.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';
import 'package:multitasking/work/work.dart';

Future<void> main(List<String> args) async {
  _header('Terminate (force = false)');
  final work1 = Work.create(_computeAsync);
  print('work1 is ${work1.runtimeType}');
  Timer(Duration(milliseconds: 100), work1.terminate);
  try {
    await work1.run();
  } catch (e) {
    print('Error: $e');
  }

  _header('Terminate using a cancellation token');
  final cts = CancellationTokenSource();
  final work2 = Work.create(_computeWithToken, token: cts.token);
  print('work2 is ${work2.runtimeType}');
  Timer(Duration(milliseconds: 500), cts.cancel);
  try {
    await work2.run();
  } catch (e) {
    print('Error: $e');
  }
}

Future<int> _computeAsync() async {
  _message('Start');
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
  }
}

Future<int> _computeWithToken() async {
  _message('Start');
  final token = Task.token;
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: 100));
    token.throwIfCanceled();
  }
}

void _header(String text) {
  print('-' * 40);
  print(text);
}

void _message(Object object) {
  print('Zone(${Zone.current.hashCode}): $object');
}

```

Output:

```txt
----------------------------------------
Terminate (force = false)
work1 is IsolatedWork<int>
Zone(987377218): Start
Error: CancellationException
----------------------------------------
Terminate using a cancellation token
work2 is IsolatedWork<int>
Zone(1027053624): Start
Error: CancellationException

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

Future<void> main() async {
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

Future<void> main() async {
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

Future<void> main() async {
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

Future<void> main() async {
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
Task(1): Increment counter: 1
Task(1): Increment counter: 2
Task(1): Increment counter: 3
Task(3): Increment counter: 4
Task(3): Increment counter: 5
Task(3): Increment counter: 6
Task(4): Increment counter: 7
Task(4): Increment counter: 8
Task(4): Increment counter: 9

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

Future<void> main() async {
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
Task(1): Enter
Task(1): Leave
Task(3): Enter
Task(3): Leave
Task(4): Enter
Task(4): Leave

```

### Multiple write single read object

A `MultipleWriteSingleReadObject`is a synchronized object.

If an object is not held by one or more `writers`, then `readers` can access the value of and object (using the `read` method) without any delay, having previously checked the state of the object by reading the value `isLocked`.

If a object is held by one or more `writers`, then `readers` must waiting for the `write` operations to complete using the `wait` method.\
After that, a value can be accessed immediately using the `read` method.

If an object is held by one or more `readers` and a `write` operation is requested, the `writer` will wait  for all previous `read` and `write`
operations.

An example of reading and writing a shared object simultaneously:

[example/example_multiple_write_single_read_object.dart](https://github.com/mezoni/multitasking/blob/main/example/example_multiple_write_single_read_object.dart)

```dart
import 'package:multitasking/multitasking.dart';
import 'package:multitasking/synchronization/multiple_write_single_read_object.dart';

Future<void> main() async {
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
Task(1): read 0
Task(3): wait write
Task(4): wait write
Task(5): wait read
Task(3): write 1
Task(6): wait read
Task(4): write 2
Task(5): read (after wait) 2
Task(6): read (after wait) 2
Task(7): read 2

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

Future<void> main() async {
  final mre = ManualResetEvent(false);
  final watch = Stopwatch();
  final tasks = <AnyTask>[];
  for (var i = 0; i < 3; i++) {
    final task = Task.run(() async {
      await mre.wait();
      _message('${watch.elapsedMilliseconds}');
    });

    tasks.add(task);
  }

  const ms = 500;
  watch.start();
  _message('${watch.elapsedMilliseconds}');
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
Task(1): 510
Task(3): 512
Task(4): 512

```
