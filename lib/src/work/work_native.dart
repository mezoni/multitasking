import 'dart:async';

import '../../multitasking.dart';
import '../../work/isolated_work.dart';
import '../../work/work.dart';

/// Returns an instance of [IsolatedWork].
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
  return IsolatedWork(computation, token: token);
}
