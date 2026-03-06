# Changelog

## 2.8.0

- Changed the link to the image `mutex.gif`.

## 2.7.0

- Fixed a bug with incorrect use of `WaitQueue`.
- Fixed a bug in `ConditionVariable`.
- Added image `assets/images/mutex.gif`.

## 2.6.0

- Slightly improved `ReentrantLock` performance.
- The internal algorithm for processing the `Task` result has been slightly changed.
- Added getters for the `Task`, for each task state (eg. `isCompleted` for the `TaskState.completed` state).
- Breaking change: The `Synchronizer` class has been renamed to `Lock`.

## 2.5.0

- Slightly improved `BinarySemaphore` performance.
- Slightly improved `ReentrantLock` performance.
- Changed example `example_task_cancel_long_network.dart`.
- Changed example `example_task_cancel_network.dart`.
- Changed example `example_task_cancel_await_for_stream_emulation.dart`.
- Breaking change: Removed `Task.awaitFor` method.
- Added class `ForEach`.

## 2.4.0

- Breaking change: Removed type parameter from `ReentrantLock` class.

## 2.3.0

- Added table of contents in file `README.md`.
- Added class `ReentrantLock`.
- Added example `example_reentrant_lock.dart`.

## 2.2.0

- Added an explanation of the operating principle and internal structure of the task.
- Changed package description.
- A unified mechanism for implementing a waiting queue has been added  (`WaitQueue`).
- Breaking change:The signatures of some synchronization primitives have been changed to consistently use wait queues. This applies to methods that implement waiting with a timeout (`tryWait()`).

## 2.1.0

- Added example `example_counting_semaphore.dart`.
- Added example `example_task_cancel_await_for_stream.dart`.
- Added method `static Task<void> awaitFor<R>(Stream<R> stream, CancellationToken token, bool Function(R) f)`.
- Added class `CountingSemaphore`.
- Added class: `BinarySemaphore`.
- Breaking change: The functionality of the `CancellationToken` handler has been changed. Performance and usability have been improved, and most importantly, the restriction on linking to a single task has been lifted.
- Added example `example_task_cancel_during_sleep.dart`.
- Added example `example_binary_semaphore.dart`.
- Added class `Synchronizer`.
- Added class `ConditionVariable`.
- Added example `example_condition_variable.dart`.

## 2.0.0

- Breaking change: Removed support for unsafe task termination.
- Added support for safe task cancellation.

## 1.2.0

- Minor corrections have been made to the examples.

## 1.1.0

- Fixed a bug that did not take into account that in Dart, a function cannot return a `Future<Future<T>>` result. Dart automatically `flattens` this value to `Future<T>`.
- Changed signature of the following methods in the `Task` class: `Future<Task<T>> run()`, `Future<void> start()` to `Task<T> run()`, `void start()`. First method (`run`) was changed because Dart blocks `Future<Task<T>> Task<T>.run)` until the task completes, the second method (`start`) was changed to be consistent with the first.

## 1.0.0

- Initial release.
