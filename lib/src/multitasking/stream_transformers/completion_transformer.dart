import 'dart:async';

/// A [StreamCompletion] is a mechanism for tracking the completion status
/// ([StreamStatus]) of a stream.
///
/// This mechanism can be activated using other mechanisms that handle stream
/// state events at the time of the stream termination.
///
/// The simplest and most convenient way to use it is to use a [???]
/// transformer.
class StreamCompletion {
  final _completer = Completer<StreamStatus>();

  Object? _error;

  StreamStatus? _status;

  StackTrace? _stackTrace;

  /// Waits for the stream to terminate and returns the stream completion
  /// status.
  Future<StreamStatus> wait() {
    return _completer.future;
  }

  /// An event handler to be called when the stream subscription is canceled.
  void onCancel() {
    _checkCompletionState();
    _status = const StreamStatusCanceled();
  }

  /// An event handler to be called when the stream completes successfully.
  void onDone() {
    _checkCompletionState();
    _status = const StreamStatusDone();
  }

  /// An event handler to be called when an error is added to the stream.
  void onError(Object error, StackTrace stackTrace) {
    _checkCompletionState();
    _error = error;
    _stackTrace = stackTrace;
  }

  /// The handler to be called when the stream terminates.
  void terminate() {
    if (_completer.isCompleted) {
      throw StateError("The 'terminate()' method can be called only once");
    }

    var status = _status;
    status ??= _error != null ? StreamStatusError(_error!, _stackTrace!) : null;
    if (status == null) {
      throw StateError(
          'Failed to handle termination, completion status is not determined');
    }

    _completer.complete(status);
    _error = null;
    _stackTrace = null;
  }

  void _checkCompletionState() {
    if (_completer.isCompleted) {
      throw StateError(
          "Failed to set completion status, 'StreamCompletion' is already completed");
    }

    if (_status != null) {
      throw StateError(
          "Failed to set completion status, status was already set");
    }
  }
}

/// A [StreamStatus] is the status of the stream after the stream has completed.
sealed class StreamStatus {
  const StreamStatus();
}

/// A [StreamStatusCanceled] is the status of the stream after the stream has
/// completed when the stream subscription method `cancel()` is called.
class StreamStatusCanceled extends StreamStatus {
  /// Creates an instance of [StreamStatusCanceled].
  const StreamStatusCanceled();

  @override
  String toString() {
    return 'canceled';
  }
}

/// A [StreamStatusDone] is the status of the stream after the stream has
/// successfully completed.
class StreamStatusDone extends StreamStatus {
  /// Creates an instance of [StreamStatusDone].
  const StreamStatusDone();

  @override
  String toString() {
    return 'done';
  }
}

/// A [StreamStatusError] is the status of the stream after the stream has
/// completed with an error.
class StreamStatusError extends StreamStatus {
  /// The error that caused the thread to terminate.
  final Object error;

  /// Stack trace for the error.
  final StackTrace stackTrace;

  /// Creates an instance of [StreamStatusError].
  ///
  /// Parameters:
  ///
  /// - [error]: The error that caused the thread to terminate.
  /// - [stackTrace]: Stack trace for the error.
  const StreamStatusError(this.error, this.stackTrace);

  @override
  String toString() {
    return 'error';
  }
}
