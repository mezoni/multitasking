import 'dart:async';

import '../../multitasking.dart';
import '../../work/work.dart';
import '../../work/zoned_work.dart';

/// Returns an instance of [ZonedWork].
///
/// Parameters:
///
/// - [computation]: A callback that represents a computation.
/// - [token]: Cancellation token used for canceling the execution of
/// computation.
///
/// If the [token] parameter is specified, it can be retrieved in the
/// computation] body by calling [Task.token].\
/// Token-based cancellation is a very flexible cancellation method,
/// implemented solely based on the cancellation request processing logic.
Work<T> createWork<T>(
  FutureOr<T> Function() computation, {
  CancellationToken? token,
}) {
  return ZonedWork(computation, token: token);
}
