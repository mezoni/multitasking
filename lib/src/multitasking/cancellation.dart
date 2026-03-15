import 'dart:async';

import 'errors.dart';

/// Performs the following actions:
///
/// - Creates a separate zone for catching exceptions
/// - Executes the [action] function
/// - Waits for the function [action] to complete and returns the result (value
/// or error)
/// - Ignores (suppresses) all unhandled exceptions in the created zone after
/// returning the result
///
/// This method can be used for the case where a synchronous method (e.g.
/// `close()`) does not throw an exception immediately, but may throw it later
/// asynchronously.\
/// This can be useful in cases where it is known in advance that an error will
/// (or may) be thrown, and this situation will be handled in a special way.
Future<T> runAndDetach<T>(FutureOr<T> Function() action) {
  final completer = Completer<T>();
  runZonedGuarded(() async {
    final result = await action();
    completer.complete(result);
  }, (error, stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  });

  return completer.future;
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
Future<void> runCancellable(
  CancellationToken token,
  void Function() onCancel,
  FutureOr<void> Function() action,
) async {
  var isExceptionThrown = false;
  final handler = token.addHandler(() {
    onCancel();
  });

  try {
    await action();
  } catch (e) {
    if (e is TaskCanceledError) {
      isExceptionThrown = true;
    }

    rethrow;
  } finally {
    token.removerHandler(handler);
    if (token.isCancelled && !isExceptionThrown) {
      token.throwIfCancelled();
    }
  }
}

class CancellationToken {
  final Map<FutureOr<void> Function(), Zone> _handlers = {};

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
  FutureOr<void> Function()? addHandler(FutureOr<void> Function() callback) {
    if (_isCancelled) {
      scheduleMicrotask(callback);
      return null;
    }

    final zone = Zone.current;
    _handlers[callback] = zone;
    return callback;
  }

  // Removes the handler.\
  // The subscriber must call this method itself after the handler is no longer
  // needed to free up memory.
  void removerHandler(FutureOr<void> Function()? callback) {
    if (callback != null) {
      _handlers.remove(callback);
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
    final handlers = {...token._handlers};
    token._handlers.clear();
    for (final entry in handlers.entries) {
      final callback = entry.key;
      final zone = entry.value;
      zone.scheduleMicrotask(callback);
    }
  }
}
