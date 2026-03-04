import 'errors.dart';

class CancellationToken {
  final Set<void Function()> _handlers = {};

  bool _isCancelled = false;

  CancellationToken._();

  /// Returns the state of the token.
  bool get isCancelled {
    return _isCancelled;
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
  void Function()? addHandler(void Function() handler) {
    if (_isCancelled) {
      handler();
      return null;
    }

    _handlers.add(handler);
    return handler;
  }

  // Removes the handler.\
  // The subscriber must call this method itself after the handler is no longer
  //needed to free up memory.
  void removerHandler(void Function()? handler) {
    if (handler != null) {
      _handlers.remove(handler);
    }
  }

  // Throw the exception [TaskCanceledError] if the token is in the `canceled`
  // state.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw TaskCanceledError();
    }
  }
}

class CancellationTokenSource {
  final CancellationToken token = CancellationToken._();

  // Sets the token state to `canceled`.
  void cancel() {
    token._isCancelled = true;
    final handlers = token._handlers.toList();
    for (final handler in handlers) {
      handler();
    }

    token._handlers.clear();
  }
}
