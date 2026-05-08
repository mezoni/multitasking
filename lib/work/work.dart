import 'dart:async';

import '../multitasking.dart';
import '../src/work/work_stub.dart'
    if (dart.library.io) 'package:multitasking/src/work/work_native.dart'
    if (dart.library.html) 'package:multitasking/src/work/work_web.dart';

/// A [Work] is an operation for executing a computation inside the container
/// with the possibility of externally controlled termination.
abstract class Work<T> {
  /// Executes the computation and returns the computation result (or throws the
  /// exception), or throws the [CancellationException] exception.
  Future<T> run();

  /// Requests to terminate the execution of a computation.
  ///
  /// Parameters:
  ///
  /// - [force]: Determines whether the execution of the computation will be
  /// terminate immediately or when control is yielded back to the event loop.
  ///
  /// Not all platforms support forced termination.\
  /// The `web` platform does not support forced termination.
  void terminate({bool force = false});

  /// Returns an instance of [Work] depending on the platform (for
  /// the `native` platform it is `IsolatedContext`, for the `web` platform it
  /// is `ZonedContext`).
  ///
  /// Parameters:
  ///
  /// - [computation]: A callback that represents a computation.
  /// - [token]: Cancellation token used for canceling the execution of
  /// computation.
  ///
  /// If the [token] parameter is specified, it can be retrieved in the
  /// [computation] body by calling [Task.token].\
  /// Token-based cancellation is a very flexible cancellation method,
  /// implemented solely based on the cancellation request processing logic.
  static Work<T> create<T>(
    FutureOr<T> Function() computation, {
    CancellationToken? token,
  }) {
    return _createPlatformSpecificContext(computation, token: token);
  }

  static Work<T> _createPlatformSpecificContext<T>(
    FutureOr<T> Function() computation, {
    CancellationToken? token,
  }) {
    return createWork(computation, token: token);
  }
}
