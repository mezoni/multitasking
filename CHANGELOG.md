## 2.0.0

- Breaking change: Removed support for unsafe task termination.
- Added support for safe task cancellation.

## 1.2.0

- Minor corrections have been made to the examples.

## 1.1.0

- Fixed a bug that did not take into account that in Dart, a function cannot return a `Future<Future<T>>` result. Dart automatically `flattens` this value to `Future<T>`.
- Changed signature of the following methods in the `Task` class: `Future<Task<T>> run()`, `Future<void> start()` to `Task<T> run()`, `void start()`. First method (`run`) was changed because Dart blocks `Future<Task<T>> Task<T>.run)` until the task completes, the second method (`start`) was changed to be consistent with the first.

## 1.0.0

- Initial release
