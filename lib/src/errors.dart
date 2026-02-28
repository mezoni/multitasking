import 'dart:collection';

import 'package:async/async.dart';
import 'package:stack_trace/stack_trace.dart';

/// Represents an error that aggregates other errors and their stack traces.
class AggregateError extends _Error {
  final List<ErrorResult> _exceptions;

  @override
  final StackTrace stackTrace;

  AggregateError(List<ErrorResult> exceptions)
      : _exceptions = UnmodifiableListView(exceptions),
        stackTrace = _buildAggregateStackTrace(exceptions) {
    if (exceptions.isEmpty) {
      throw ArgumentError('Exception list must not be empty', 'exceptions');
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('One or more errors occurred. ');
    buffer.write(_exceptions.map((e) => '(${e.error})').join(' '));
    return '$buffer';
  }

  static StackTrace _buildAggregateStackTrace(List<ErrorResult> exceptions) {
    final frames = exceptions.map((e) => e.stackTrace).map(Trace.from);
    final chain = Chain(frames);
    return chain;
  }
}

/// Represents the error that will be thrown if the task is stopped.
class TaskStoppedError extends _Error {
  TaskStoppedError([super.message]);
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
