## 1.1.0

- Fixed a bug that did not take into account that in Dart, a function cannot return a `Future<Future<T>>` result. Dart automatically `flattens` this value to `Future<T>`.
- Changed signature of the following methods: `Future<Task<T>> Task<T>.run`, `Future<void> Task.start` to `Task<T> Task<T>.run`, `void Task.start`. First method (`run`) was changed because Dart blocks `Future<Task<T>> Task<T>.run)` until the task completes, the second method (`start`) was changed to be consistent with the first.

## 1.0.0

- Initial release
