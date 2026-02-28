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

BEGIN_EXAMPLE
example_task_stop_stream
END_EXAMPLE

Example from this source: [CancelableOperation and CancelableCompleter should cancel/kill delayed Futures](https://github.com/dart-lang/language/issues/1629)

Example based on what is described in the source:

BEGIN_EXAMPLE
example_task_stop_simple
END_EXAMPLE

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

BEGIN_EXAMPLE
example_task_stop_group
END_EXAMPLE

Example of stopping a group of tasks in case of any failure in any task.  
The example may seem complicated to implement, but it can be implemented in a function or helper class.  

Brief scenario:

1. Create a parent task
2. Create child tasks in the body of the parent task
3. Wait all child tasks in the body of the parent task (it will fails if any child task fails)
4. Add a `onExit` handler to the parent task and to all child tasks that will stop the all tasks if any task fails.
5. Throw an exception in a child task

BEGIN_EXAMPLE
example_task_stop_group_by_failure
END_EXAMPLE

**When a task completes executing its action body, it completely disables everything that can be disabled.**

The main job of a task is to execute an action. Everything else is secondary.  
This statement is true for the zone in which the `task action` are executed.  
Each task is executed in its own zone and, accordingly, cannot in any way affect on other tasks.

Brief scenario:

1. Create a task
2. Create a periodic timer in the task body
3. See what happens when task complete

Example with periodic timer:

BEGIN_EXAMPLE
example_task_stop_periodic_timer
END_EXAMPLE

Brief scenario:

1. Create a task
2. In the task body, schedule a microtask that will create a timer.
3. In the timer callback function, schedule a microtask that will create the timer.
4. See what happens when task complete

Example with periodic timer:

BEGIN_EXAMPLE
example_task_stop_microtask
END_EXAMPLE
