# Multitasking

Cooperative multitasking using asynchronous tasks, with support for forced task termination with `onExit` handlers.

Version: 1.0.0

## About this software

Cooperative multitasking using asynchronous tasks, with support for forced task termination with `onExit` handlers.  
The tasks is implemented using the following standard core classes:  

- [Zone](https://api.dart.dev/dart-async/Zone-class.html)
- [Zone specification](https://api.dart.dev/dart-async/ZoneSpecification-class.html)
- [Future](https://api.dart.dev/dart-async/Future-class.html)
- [Finalizer](https://api.dart.dev/dart-core/Finalizer-class.html)

## Practical use

Tasks are executed asynchronously and cooperatively.\
Tasks are very lightweight objects. The actions performed by tasks are not much slower than those performed by futures.\
Provided that these are not elementary actions like (a + b).\

Tasks can be used together with other software that implements additional functionality.\
For example, in combination with software that implements the preemptive multitasking (starting and stopping by request).\
Tasks can be used as building blocks with helper functions to implement complex algorithms.

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

**Each task runs in its own zone. When the computation action completes, the task zone deactivated**:

This includes the following:

- All active timers are deactivated
- All created timers are deactivated immediately after they are created
- Any pending callbacks will be executed as the empty action callbacks
- All micro tasks scheduling calls are replaced with empty action callbacks
- In all the `registerCallback` methods, the callback is replaced with a callback with the exception of [TaskStoppedError].

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
  final task = await Task.run<int>(() => throw 'Error');

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
  final task = await Task.run<int>(() {
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
  final task = await Task.run<int>(name: 'my task', () {
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

**The task can be stopped.**

The execution of asynchronous task code can be stopped.  
⚠️ Important information:  
The execution of synchronous task code cannot be stopped.

A  task is stopped at an unpredictable execution point. If possible, it is recommended to stop task in a more gentle way.  
But if it is still absolutely necessary to stop the task, then why not use this method?

Remark:  
The terms `parent task` and `child task` are rather arbitrary, since there is no real relationship between these tasks.  
They are used to simplify the logical understanding of the interaction of tasks.  
The interaction logic is completely determined by the developer.

Brief scenario:

1. Create task with `StreamController controller` and start an infinite loop
2. Create task that subscribes to `controller.stream` using an `await for` statement
3. Stop controller task
4. Stop subscriber task

Example of stopping these tasks:

[example/example_task_stop_stream.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_stream.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final controller = StreamController<int>();
  final master = await Task.run<void>(name: 'master', () async {
    Task.onExit((task) {
      print('Exit $task');
      if (!controller.isClosed) {
        print('$task closing controller');
        controller.close();
      }
    });

    var i = 0;
    Timer.periodic(Duration(seconds: 1), (timer) {
      controller.add(i++);
    });

    // Wait  forever
    await Completer<void>().future;
  });

  final stream = controller.stream;
  final slave = await Task.run<void>(name: 'slave', () async {
    Task.onExit((task) {
      print('Exit $task');
    });

    await for (final value in stream) {
      print(value);
      await Task.sleep();
    }
  });

  Timer(Duration(seconds: 3), () {
    print('Stop $slave');
    slave.stop();
    print('Stop $master');
    master.stop();
  });

  try {
    await Task.waitAll([master, slave]);
  } catch (e) {
    print(e);
  }

  print('Tasks stopped');
}

```

Output:

```txt
0
1
2
Stop Task('slave', 2)
Exit Task('slave', 2)
Stop Task('master', 0)
Exit Task('master', 0)
Task('master', 0) closing controller
One or more errors occurred. (TaskStoppedError) (TaskStoppedError)
Tasks stopped

```

Example from this source: [CancelableOperation and CancelableCompleter should cancel/kill delayed Futures](https://github.com/dart-lang/language/issues/1629)

Example based on what is described in the source:

[example/example_task_stop_simple.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_simple.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  const duration = Duration(seconds: 5);
  final task = Task(name: 'my task', () async {
    Task.onExit((task) {
      print('On exit: $task, state: \'${task.state.name}\'');
    });

    print('running...');
    await Future<void>.delayed(duration);
    print('done');
  });

  await task.start();
  print('Stop $task with state \'${task.state.name}\'');
  task.stop();
  try {
    await task;
  } catch (e, s) {
    print('Big bada boom?');
    print('$e\n$s');
    print('Oh no, it was just a faint hiss...');
  }

  print('Waiting ${duration.inSeconds} sec. to see what happens...');
  await Future<void>.delayed(duration);
  print('Continue to work');
}

```

Output:

```txt
running...
Stop Task('my task', 0) with state 'running'
On exit: Task('my task', 0), state: 'stopped'
Big bada boom?
TaskStoppedError
#0      Task.stop (package:multitasking/src/task.dart:211:7)
#1      main (file:///home/andrew/prj/multitasking/example/example_task_stop_simple.dart:19:8)
<asynchronous suspension>

Oh no, it was just a faint hiss...
Waiting 5 sec. to see what happens...
Continue to work

```

**The task can be stopped as a group of tasks.**

The parent task can stop child tasks at its discretion.  
During development, this can be done as required for logical operation.

Brief scenario:

1. Create a parent task
2. Create child tasks in the body of the parent task
3. Wait all child tasks in the body of the parent task (it will fails if any child task fails)
4. Add a `onExit` handler to the parent task that will stop the child tasks when the parent task completes unsuccessfully
5. Stop the parent task by timer

An example of stopping a task group by stopping the parent task:

[example/example_task_stop_group.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_group.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final group = <Task<int>>[];
  final parent = await Task.run<void>(name: 'Parent', () async {
    Task.onExit((me) {
      print('On exit: $me (${me.state.name})');
      if (me.state != TaskState.completed) {
        for (var i = 0; i < group.length; i++) {
          final task = group[i];
          if (!task.isTerminated) {
            print('${me.name} stops \'${task.name}\' (${task.state.name})');
            task.stop();
          }
        }
      }
    });

    for (var i = 0; i < 3; i++) {
      final t = await Task.run<int>(name: 'Child $i', () async {
        Task.onExit((task) {
          print('On exit: $task (${task.state.name})');
        });

        var result = 0;
        for (var i = 0; i < 5; i++) {
          print('${Task.current} works: $i of 4');
          result++;
          await Future<void>.delayed(Duration(seconds: 2));
        }

        return result;
      });

      group.add(t);
    }

    await Task.waitAll(group);
  });

  Timer(Duration(seconds: 2), () {
    print('Stopping $parent');
    parent.stop();
  });

  try {
    await parent;
  } catch (e) {
    //
  }
}

```

Output:

```txt
Task('Child 0', 2) works: 0 of 4
Task('Child 1', 3) works: 0 of 4
Task('Child 2', 4) works: 0 of 4
Task('Child 0', 2) works: 1 of 4
Task('Child 1', 3) works: 1 of 4
Stopping Task('Parent', 0)
On exit: Task('Parent', 0) (stopped)
Parent stops 'Child 0' (running)
On exit: Task('Child 0', 2) (stopped)
Parent stops 'Child 1' (running)
On exit: Task('Child 1', 3) (stopped)
Parent stops 'Child 2' (running)
On exit: Task('Child 2', 4) (stopped)

```

Example of stopping a group of tasks in case of any failure in any task.  
The example may seem complicated to implement, but it can be implemented in a function or helper class.  

Brief scenario:

1. Create a parent task
2. Create child tasks in the body of the parent task
3. Wait all child tasks in the body of the parent task (it will fails if any child task fails)
4. Add a `onExit` handler to the parent task and to all child tasks that will stop the all tasks if any task fails.
5. Throw an exception in a child task

[example/example_task_stop_group_by_failure.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_group_by_failure.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  late AnyTask parent;
  final group = <Task<int>>[];

  void onExit(AnyTask task) {
    void stop(AnyTask task) {
      if (!task.isTerminated) {
        task.stop();
      }
    }

    if (task.state != TaskState.completed) {
      for (final task in group) {
        stop(task);
      }
    }

    stop(parent);
  }

  parent = await Task.run<void>(name: 'Parent', () async {
    Task.onExit((task) {
      print('On exit: $task (${task.state.name})');
      onExit(task);
    });

    for (var i = 0; i < 3; i++) {
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
    }

    await Task.waitAll(group);
  });

  try {
    await parent;
  } catch (e) {
    //
  }
}

```

Output:

```txt
Task('Child 0', 2) works: 0 of 4
Task('Child 1', 3) works: 0 of 4
Task('Child 2', 4) works: 0 of 4
Task('Child 0', 2) works: 1 of 4
On exit: Task('Child 1', 3) (failed)
On exit: Task('Child 0', 2) (stopped)
On exit: Task('Child 2', 4) (stopped)
On exit: Task('Parent', 0) (stopped)

```

**When a task completes executing its action body, it completely disables everything that can be disabled.**

The main job of a task is to execute an action. Everything else is secondary.  
This statement is true for the zone in which the `task action` are executed.  
Each task is executed in its own zone and, accordingly, cannot in any way affect on other tasks.

Brief scenario:

1. Create a task
2. Create a periodic timer in the task body
3. See what happens when task complete

Example with periodic timer:

[example/example_task_stop_periodic_timer.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_periodic_timer.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = await Task.run(name: 'task with timer', () async {
    Timer.periodic(Duration(milliseconds: 500), (_) {
      print('tick');
    });

    await Task.sleep(1500);
  });

  await task;
  print('$task ${task.state.name}');
  await Task.sleep(1500);
  print('Let\'s wait and see what happens.');
}

```

Output:

```txt
tick
tick
tick
Task('task with timer', 0) completed
Let's wait and see what happens.

```

Brief scenario:

1. Create a task
2. In the task body, schedule a microtask that will create a timer.
3. In the timer callback function, schedule a microtask that will create the timer.
4. See what happens when task complete

Example with periodic timer:

[example/example_task_stop_microtask.dart](https://github.com/mezoni/multitasking/blob/main/example/example_task_stop_microtask.dart)

```dart
import 'dart:async';

import 'package:multitasking/multitasking.dart';

Future<void> main() async {
  final task = await Task.run(name: 'task with timer', () async {
    scheduleMicrotask();
    await Task.sleep(1500);
  });

  await task;
  print('$task ${task.state.name}');
  await Task.sleep(1500);
  print('Let\'s wait and see what happens.');
}

void createTimer() {
  Timer(Duration(milliseconds: 500), () {
    print('tick');
    scheduleMicrotask();
  });
}

void scheduleMicrotask() {
  Zone.current.scheduleMicrotask(createTimer);
}

```

Output:

```txt
tick
tick
Task('task with timer', 0) completed
Let's wait and see what happens.

```
