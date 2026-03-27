import 'dart:async';

import 'errors.dart';

/// A [CancellationToken] is a mechanism for graceful cancellation of
/// asynchronous operations.
class CancellationToken {
  final Map<FutureOr<void> Function(), Zone> _handlers = {};

  bool _isCanceled = false;

  CancellationToken._();

  /// Returns the state of the token.
  bool get isCanceled {
    return _isCanceled;
  }

  /// Adds and returns a handler if the token is not in the `canceled` state.
  ///
  /// If the token is in the `canceled` state, the handler will be called
  /// immediately. In this case, the handler will not be added and `null` will
  /// be returned.
  ///
  /// Handlers should be added temporarily. For example, while waiting for the
  /// completion of I/O operation. To cancel this operation (for example,
  /// to call their methods `close()`, `cancel()`, etc.).
  ///
  /// After waiting for the end of the operation, the handler must explicitly
  /// removed by calling the [removerHandler] method.
  ///
  /// Example:
  ///
  /// ```dart
  /// final client = HttpClient();
  /// final handler = token.addHandler(() {
  ///   client.close(force: true);
  /// }
  /// // Some code
  /// try {
  ///   // Performing the operation
  /// } finally {
  ///   token.removerHandler(handler);
  ///   client.close();
  /// }
  /// ```
  FutureOr<void> Function()? addHandler(FutureOr<void> Function() callback) {
    if (_isCanceled) {
      scheduleMicrotask(callback);
      return null;
    }

    final zone = Zone.current;
    _handlers[callback] = zone;
    return callback;
  }

  /// Removes the handler.\
  /// The subscriber must call this method itself after the handler is no longer
  /// needed to free up memory.
  void removerHandler(FutureOr<void> Function()? callback) {
    if (callback != null) {
      _handlers.remove(callback);
    }
  }

  /// Performs the following actions:
  ///
  /// - Adds a cancellation handler [onCancel]
  /// - Executes the [action] function
  /// - Removes a cancellation handler [onCancel]
  /// - Throws an [TaskCanceledError] exception if there was a cancellation
  /// request and no [TaskCanceledError] exception was thrown during the
  /// execution of the [action] function
  ///
  /// The [onCancel] handler function should initiate the cancellation procedure
  /// which interrupts (or cancel) the execution of the [action] function.
  Future<T> runCancelable<T>(
    void Function() onCancel,
    FutureOr<T> Function() action,
  ) async {
    var isExceptionThrown = false;
    final handler = addHandler(() {
      onCancel();
    });

    try {
      return await action();
    } catch (e) {
      if (e is TaskCanceledException) {
        isExceptionThrown = true;
      }

      rethrow;
    } finally {
      removerHandler(handler);
      if (isCanceled && !isExceptionThrown) {
        throwIfCanceled();
      }
    }
  }

  /// Throw the exception [TaskCanceledError] if the token is in the `canceled`
  /// state.
  void throwIfCanceled() {
    if (_isCanceled) {
      throw TaskCanceledException();
    }
  }

  void _cancel() {
    _isCanceled = true;
    final entries = _handlers.entries.toList();
    _handlers.clear();
    for (final entry in entries) {
      final callback = entry.key;
      final zone = entry.value;
      zone.scheduleMicrotask(callback);
    }
  }
}

/// A [CancellationTokenSource] class manages the cancellation process for
/// asynchronous operations.\
/// It works in conjunction with the [CancellationToken] class, providing a
/// `cooperative` cancellation mechanism.
class CancellationTokenSource {
  final CancellationToken token = CancellationToken._();

  Timer? _timer;

  /// Signal to associated token that the operation executions should be
  /// canceled.
  void cancel() {
    token._cancel();
  }

  /// Signal to associated token that the operation executions should be
  /// canceled after the specified [duration].
  ///
  /// Subsequent calls to [cancelAfter] will reset the [duration] for this
  /// [CancellationTokenSource], if it has not been canceled already.
  void cancelAfter(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative');
    }

    if (token._isCanceled) {
      return;
    }

    _timer?.cancel();
    _timer = Timer(duration, token._cancel);
  }
}
