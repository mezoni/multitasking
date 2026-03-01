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

**For the current task, it is possible to specify the `onExit` handler inside the task body.**

The `OnExit` handler can be used to ensure the execution of some logical actions.

Example of `OnExit` handler:

BEGIN_EXAMPLE
example_task_on_exit
END_EXAMPLE

**The name of the task can be specified.**

Example of using a task with the name:

BEGIN_EXAMPLE
example_task_name
END_EXAMPLE

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

```dart
try {
  token.throwIfCancelled();
} finally {
  // Handle cancellation
  rethrow;
}
```

Remark:  
The terms `parent task` and `child task` are rather arbitrary, since there is no real relationship between these tasks.  
They are used to simplify the logical understanding of the interaction of tasks.  
The interaction logic is completely determined by the developer.

**The task can be cancelled as a group of tasks.**

Example of cancelled a group of tasks in case of any failure in any task.  

BEGIN_EXAMPLE
example_task_cancel_group_by_failure
END_EXAMPLE

Example of cancelled a group of tasks while working with the network.  

BEGIN_EXAMPLE
example_task_cancel_network
END_EXAMPLE

Another example of cancelled a group of tasks while working with the network.  

BEGIN_EXAMPLE
example_task_cancel_long_network
END_EXAMPLE
