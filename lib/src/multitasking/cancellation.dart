import 'dart:async';

import 'errors.dart';

/// A [CancellationToken] is a mechanism for graceful cancellation of
/// asynchronous operations.
class CancellationToken {
  final Map<FutureOr<void> Function(), Zone> _handlers = {};

  bool _isCanceled = false;

  CancellationToken._();

  /// Returns `true` if the token is in a `canceled` state.
  bool get isCanceled {
    return _isCanceled;
  }

  /// Adds and returns a handler if the token is not in the `canceled` state.\
  /// If the token is in the `canceled` state, the handler will be called
  /// immediately. In this case, the handler will not be added and `null` will
  /// be returned.
  ///
  /// Parameters:
  ///
  /// - [callback]: A callback that will `cancel` the execution of the [action].
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

  /// Removes the handler.
  ///
  /// Parameters:
  ///
  /// - [callback]: A previously added [callback] function that should be
  /// removed from the handlers.
  ///
  /// The subscriber must call this method itself after the handler is no longer
  /// needed to free up memory.
  void removerHandler(FutureOr<void> Function()? callback) {
    if (callback != null) {
      _handlers.remove(callback);
    }
  }

  /// Execute an [action] that can be canceled while it is being executed.
  ///
  /// Parameters:
  ///
  /// - [onCancel]: A callback that will `cancel` the execution of the [action].
  /// - [action]: An [action] that supports `cancellation` on request.
  ///
  /// Performs the following actions:
  ///
  /// - Adds a cancellation handler [onCancel]
  /// - Executes the [action] callback
  /// - Removes a cancellation handler [onCancel]
  ///
  /// The [onCancel] handler should initiate the cancellation which cancel the
  /// execution of the [action] callback.
  ///
  /// This method itself does not throw any exceptions. It simply calls the
  /// [onCancel] handler when a cancellation request is made.
  Future<T> runCancelable<T>(
    void Function() onCancel,
    FutureOr<T> Function() action,
  ) async {
    final handler = addHandler(() {
      onCancel();
    });
    try {
      return await action();
    } finally {
      removerHandler(handler);
    }
  }

  /// Throw the exception [TaskCanceledException] if the token is in the
  /// `canceled` state.
  void throwIfCanceled() {
    if (_isCanceled) {
      throw TaskCanceledException();
    }
  }

  void _cancel() {
    if (_isCanceled) {
      return;
    }

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

  /// Creates an instance of [CancellationTokenSource].
  ///
  /// Parameters:
  ///
  /// - [delay]: The duration after which a cancellation request is initiated,
  /// if the [delay] value is specified.
  CancellationTokenSource([Duration? delay]) {
    if (delay != null) {
      cancelAfter(delay);
    }
  }

  /// Sets the [token] to the `canceled` state.
  void cancel() {
    token._cancel();
  }

  /// Sets the [delay] time after which a cancellation request will be
  /// initiated or the time will be reset if the [delay] value is `null`.
  ///
  /// Parameters:
  ///
  /// - [delay]:The [delay] time before initiating a cancellation request.
  ///
  /// Subsequent calls to [cancelAfter] will reset the [delay] for this
  /// [CancellationTokenSource], if it has not been canceled already.
  void cancelAfter(Duration? delay) {
    if (delay == null) {
      _timer?.cancel();
      return;
    }

    if (delay.isNegative) {
      throw ArgumentError.value(delay, 'duration', 'Must not be negative');
    }

    if (token._isCanceled) {
      return;
    }

    _timer?.cancel();
    _timer = Timer(delay, token._cancel);
  }

  /// Creates a [CancellationTokenSource] that will be linked with other
  /// cancellation sources via specified [tokens].
  ///
  /// Parameters:
  ///
  /// - [token]: List of tokens of other cancellation sources to link.
  ///
  /// This [CancellationTokenSource] can be canceled individually, or it will be
  /// canceled cooperatively when one of the other sources will initiate a
  /// cancellation request.\
  /// If any of the sources has already initiated a cancellation request, then
  /// that source immediately initiate the cancellation request.
  static CancellationTokenSource createLinkedTokenSource(
      List<CancellationToken> tokens) {
    if (tokens.isEmpty) {
      throw ArgumentError('tokens', 'Must not be empty');
    }

    final cts = CancellationTokenSource();
    final handler = cts.cancel;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.isCanceled) {
        cts.cancel();
        break;
      }

      token.addHandler(handler);
    }

    return cts;
  }
}
