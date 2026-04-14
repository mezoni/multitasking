import 'dart:collection';

import 'package:async/async.dart';
import 'package:stack_trace/stack_trace.dart';

/// Represents an error that aggregates other errors amd exceptions and
/// their stack traces.
class AggregateError extends _Error {
  final List<ErrorResult> _exceptions;

  /// The stack trace associated with this error.
  @override
  final StackTrace stackTrace;

  /// Creates an instance of [AggregateError].
  ///
  /// Parameters:
  ///
  /// - [exceptions]: List of exceptions for aggregation.
  AggregateError(List<ErrorResult> exceptions)
      : _exceptions = UnmodifiableListView(exceptions),
        stackTrace = _buildAggregateStackTrace(exceptions) {
    if (exceptions.isEmpty) {
      throw ArgumentError('Must not be empty', 'exceptions');
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('AggregateError: One or more errors occurred. ');
    buffer.write(_exceptions.map((e) => '(${e.error})').join(' '));
    return '$buffer';
  }

  static StackTrace _buildAggregateStackTrace(List<ErrorResult> exceptions) {
    final frames = exceptions.map((e) => e.stackTrace).map(Trace.from);
    final chain = Chain(frames);
    return chain;
  }
}

/// Represents an exception used to signal and indicate task cancellation.
class TaskCanceledException implements Exception {
  /// Message associated with this exception.
  final String? message;

  /// Creates an instance of [TaskCanceledException].
  TaskCanceledException([this.message]);

  @override
  String toString() {
    if (message == null) {
      return 'TaskCanceledException';
    }

    return 'TaskCanceledException: $message';
  }
}

/// Represents an error that occurs when an operation is requested on a [Task]
/// whose current state does not allow the operation to be performed.
class TaskStateError extends _Error {
  /// Creates an instance of the [TaskStateError].
  ///
  /// Parameters:
  ///
  /// - [message]: Message associated with this error.
  TaskStateError([super.message]);
}

abstract class _Error extends Error {
  final String? message;

  _Error([this.message]);

  @override
  String toString() {
    final message = this.message;
    if (message == null) {
      return '$runtimeType';
    }

    return '$runtimeType: $message';
  }
}
