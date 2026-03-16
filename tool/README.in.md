# Multitasking

Cooperative multitasking using asynchronous tasks and synchronization primitives, with the ability to safely cancel groups of nested tasks performing I/O wait or listen operations.

Version: 3.5.0

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
    - [The task zone provides access to statistics of the operations in the zone](#the-task-zone-provides-access-to-statistics-of-the-operations-in-the-zone)
    - [The task can be cancelled using a cancellation token](#the-task-can-be-cancelled-using-a-cancellation-token)
    - [The task can be cancelled during `Task.sleep()`](#the-task-can-be-cancelled-during-tasksleep)
    - [The task can be cancelled as a group of tasks](#the-task-can-be-cancelled-as-a-group-of-tasks)
    - [The task can be canceled while listening to the stream](#the-task-can-be-canceled-while-listening-to-the-stream)
    - [The group of tasks can be safely cancelled while working with the network](#the-group-of-tasks-can-be-safely-cancelled-while-working-with-the-network)
    - [The tasks can be safely cancelled during long running network operation](#the-tasks-can-be-safely-cancelled-during-long-running-network-operation)
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

Very simplified `Task` code:

```dart
class Task<T> implements Future<T> {
  final FutureOr<T> Function() _action;

  final Completer<Result<T>> _taskCompleter = Completer();

  Future<T>? _future;

  Task(this._action);

  Future<T> get future async {
    if (_future != null) {
      return _future as Future<T>;
    }

    if (_state == TaskState.created) {
      throw StateError('Task has not yet been started: ${toString()}');
    }

    final result = await _taskCompleter.future;
    if (result.isValue) {
      final valueResult = result.asValue!;
      final value = valueResult.value;
      final future = Future.value(value);
      _future = future;
      return future;
    } else {
      final errorResult = result.asError!;
      _finalizer.detach(this);
      final error = errorResult.error;
      final stackTrace = errorResult.stackTrace;
      final future = Future<T>.error(error, stackTrace);
      _future = future;
      return future;
    }
  }

  Future<void> start() async {
    unawaited(runZoned(() async {
      try {
        final value = await _action();
        _complete(TaskState.completed, ValueResult(value));
      } catch (e, s) {
        _complete(TaskState.failed, ErrorResult(e, s));
      }
    }));
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return future.then(onValue, onError: onError);
  }

  void _complete(TaskState state, Result<T> result) {
    // Invoke destructor
    // Set task state and and complete `_taskCompleter`
  }
}
```

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

BEGIN_EXAMPLE
example_future
END_EXAMPLE

The same example with task:

BEGIN_EXAMPLE
example_task_await
END_EXAMPLE

A failed task does not affect the execution of other code (`Do some work`) if the task object instance is referenced.  
The task will not throw an exception until the executing code accesses the `future` field (directly or indirectly, e.g. using `await task`).

If the executing code do not access the `future` field and there are no references to the task object instance, an exception will be thrown during garbage collection when the task is finalized.  
Or it will never be thrown if the task finalization will not be performed (e.g. when the application terminates its work).

### For the current task, it is possible to specify the `onExit` handler inside the task body

The `OnExit` handler can be used to ensure the execution of some logical actions.

Example of `OnExit` handler:

BEGIN_EXAMPLE
example_task_on_exit
END_EXAMPLE

### The task immediately propagates an exception if it is an unhandled exception

An unhandled exception is considered to be an exception (except `TaskCanceledError`) that occurs after a task has completed.  
Since each task is executed in a separate zone, after the task is completed, timers (if any were created) may remain in the zone created for the task execution.  
If an exception occurs within these timers, it is considered unhandled and will be immediately propagated to the parent zone.

Example of handling unhandled exceptions:

BEGIN_EXAMPLE
example_task_handle_unhandled_error
END_EXAMPLE

### The task result can be accessed synchronously after the task is completed

An example of a synchronous access to a task result:

BEGIN_EXAMPLE
example_task_result
END_EXAMPLE

### The name of the task can be specified

Example of using a task with the name:

BEGIN_EXAMPLE
example_task_name
END_EXAMPLE

### Tasks can be waited for in different ways

Example of waiting for in different ways:

BEGIN_EXAMPLE
example_task_wait_in_different_ways
END_EXAMPLE

### The task zone provides access to statistics of the operations in the zone

Example of accessing task zone statistics:

BEGIN_EXAMPLE
example_task_zone_stats
END_EXAMPLE

### The task can be cancelled using a cancellation token

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

### The task can be cancelled during `Task.sleep()`

All that is required for this is to pass the token as an argument to method `Task.sleep()`.

Example of cancelling a task during task sleep`Task.sleep()`:

BEGIN_EXAMPLE
example_task_cancel_during_sleep
END_EXAMPLE

Remark:  
The terms `parent task` and `child task` are rather arbitrary, since there is no real relationship between these tasks.  
They are used to simplify the logical understanding of the interaction of tasks.  
The interaction logic is completely determined by the developer.

### The task can be cancelled as a group of tasks

Example of cancelled a group of tasks in case of any failure in any task:

BEGIN_EXAMPLE
example_task_cancel_group_by_failure
END_EXAMPLE

### The task can be canceled while listening to the stream

Example of canceling the emulation of the `await for` statement using `ForEach` class:

BEGIN_EXAMPLE
example_task_cancel_during_stream_iteration
END_EXAMPLE

### The group of tasks can be safely cancelled while working with the network

An example of group of tasks cancellation while working with the network:

BEGIN_EXAMPLE
example_task_cancel_network
END_EXAMPLE

### The tasks can be safely cancelled during long running network operation

An example of task cancellation during long network operation:

BEGIN_EXAMPLE
example_task_cancel_long_network
END_EXAMPLE

### Tasks can be used with `Isolate`, and all of them can be safely canceled

This example is not fundamental and is used for demonstration purposes only.

An example of using tasks with isolates and their simultaneous cancellation:

BEGIN_EXAMPLE
example_task_cancel_isolate
END_EXAMPLE

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

BEGIN_EXAMPLE
example_counting_semaphore
END_EXAMPLE

### Binary semaphore

A `BinarySemaphore` is a synchronization primitive with an integer value restricted to 0 or 1, representing locked (0) or unlocked (1) states.

Unlike a mutex, a semaphore is a counting-based synchronizer.  
If a semaphore is locked, it will be locked even for the current zone.

If a mutex is owned by a zone, it will not block this zone. It will count the number of times it is entered and leaved by zone before
releasing.

An example of using a binary semaphore as a locking mechanism:

BEGIN_EXAMPLE
example_binary_semaphore
END_EXAMPLE

### Condition variable

A `ConditionVariable` is a synchronization primitive  that allows to wait for a particular condition to become `true` before proceeding.\
It is always used in conjunction with a locking to safely manage access to the shared data and prevent race conditions.

An example of using two condition variables in conjunction with a binary semaphore (as a synchronization mechanism):

BEGIN_EXAMPLE
example_condition_variable
END_EXAMPLE

### Reentrant lock

A `ReentrantLock` is a synchronization primitive that works like a mutex.  
It blocks execution of all zones that do not own this lock.  
The zone that acquired the permit becomes the owner of this lock.  
The zone owner can enter and exit as long as it holds this lock.

An example of reentering a `ReentrantLock`:

BEGIN_EXAMPLE
example_reentrant_lock
END_EXAMPLE

### Lock interface

A `Lock` is an interface that simplifies the use of `locking` primitives.  
For example, this interface is implemented by the classes `BinarySemaphore` and  `ReentrantLock`.  
These classes can be used for exclusive locking.  

An example of using a binary semaphore as a locking mechanism:

BEGIN_EXAMPLE
example_lock
END_EXAMPLE

### Multiple write single read object

A `MultipleWriteSingleReadObject`is a synchronized object.

If an object is not held by one or more `writers`, then `readers` can access the value of and object (using the [read] method) without any delay, having previously checked the state of the object by reading the value [isLocked].

If a object is held by one or more `writers`, then `readers` must waiting for the `write` operations to complete using the [wait] method.\
After that, a value can be accessed immediately using the [read] method.

If an object is held by one or more `readers` and a `write` operation is requested, the `writer` will wait  for all previous `read` and `write`
operations.

An example of reading and writing a shared object simultaneously:

BEGIN_EXAMPLE
example_multiple_write_single_read_object
END_EXAMPLE

### Manual reset event

A `ManualResetEvent` is a synchronization primitive that is used to manage signaling.  
When an event is in a `signaled` state, any calls to the `wait()` method will not block execution of the calling code.  
When an event is in a `non-signaled` state, any calls to the `wait()` method will block execution of the calling code.

Once switched to the `signaled` state, the event remains in the `signaled` state until it is manually `reset()`.

An example of using a manual reset event to start tasks simultaneously.

BEGIN_EXAMPLE
example_manual_reset_event
END_EXAMPLE
