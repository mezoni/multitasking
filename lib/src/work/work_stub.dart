import 'dart:async';

import '../../multitasking.dart';
import '../../work/work.dart';

/// Implemented in `work_native.dart` and `work_web.dart`.
Work<T> createWork<T>(
  FutureOr<T> Function() computation, {
  CancellationToken? token,
}) {
  throw UnimplementedError(
      "'createWork()' is not implemented for the current platform");
}
