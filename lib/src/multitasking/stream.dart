import 'dart:async';

import 'package:async/async.dart';

import 'cancellation.dart';
import 'errors.dart';

/// Represents the lifecycle events of a stream subscription.
enum SubscriptionEvent {
  /// Triggered when the listener subscribes to the stream.
  start,

  /// Triggered when the subscription is paused.
  pause,

  /// Triggered when a paused subscription is resumed.
  resume,

  /// Triggered when the listener cancels their subscription.
  cancel,

  /// Triggered when the stream encounters an error.
  error,

  /// Triggered when the stream completes successfully.
  done,
}

class _CancelableStream<T> extends StreamView<T> {
  final Stream<T> _stream;

  final bool _throwIfCanceled;

  final CancellationToken _token;

  _CancelableStream(
    super.stream,
    CancellationToken token, {
    required bool throwIfCanceled,
  })  : _stream = stream,
        _token = token,
        _throwIfCanceled = throwIfCanceled;

  @override
  StreamSubscription<T> listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listenWithCancellation(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
      token: _token,
      throwIfCanceled: _throwIfCanceled,
    );
  }
}

class _StreamSubscriptionWithTracking<T>
    extends DelegatingStreamSubscription<T> {
  void Function()? _handleDone;

  Function? _handleError;

  final void Function(SubscriptionEvent event) _onEvent;

  _StreamSubscriptionWithTracking(
    super.source,
    void Function(SubscriptionEvent event) onEvent, {
    required void Function()? handleDone,
    required Function? handleError,
  })  : _handleDone = handleDone,
        _handleError = handleError,
        _onEvent = onEvent;

  @override
  Future<void> cancel() async {
    try {
      await super.cancel();
    } finally {
      _onEvent(SubscriptionEvent.cancel);
    }
  }

  @override
  void onDone(void Function()? handleDone) {
    _handleDone = handleDone;
  }

  @override
  void onError(Function? handleError) {
    _handleError = handleError;
  }

  @override
  void pause([Future<dynamic>? resumeFuture]) {
    try {
      super.pause(resumeFuture);
    } finally {
      _onEvent(SubscriptionEvent.pause);
    }
  }

  @override
  void resume() {
    try {
      super.resume();
    } finally {
      _onEvent(SubscriptionEvent.resume);
    }
  }
}

class _StreamWithSubscriptionTracking<T> extends StreamView<T> {
  final void Function(SubscriptionEvent event) _onEvent;

  final Stream<T> _stream;

  _StreamWithSubscriptionTracking(
    super.stream,
    void Function(SubscriptionEvent event) onEvent,
  )   : _onEvent = onEvent,
        _stream = stream;

  @override
  StreamSubscription<T> listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _StreamSubscriptionWithTracking<T>? sub;

    void handleDone() {
      final handleDone = sub!._handleDone;
      try {
        if (handleDone != null) {
          handleDone();
        }
      } finally {
        _onEvent(SubscriptionEvent.done);
      }
    }

    void handleError(Object error, StackTrace stackTrace) {
      final handleError = sub!._handleError;
      try {
        if (handleError != null) {
          void Function(Object error, StackTrace)? errorCallback;
          if (onError != null) {
            if (onError is void Function(Object, StackTrace)) {
              errorCallback = onError;
            } else if (onError is void Function(Object)) {
              errorCallback = (error, _) {
                onError(error);
              };
            } else {
              throw StateError(
                'Error handler must accept one Object or one Object and a StackTrace as arguments',
              );
            }
          }

          if (errorCallback != null) {
            errorCallback(error, stackTrace);
          }
        }
      } finally {
        _onEvent(SubscriptionEvent.error);
      }
    }

    _onEvent(SubscriptionEvent.start);
    sub = _StreamSubscriptionWithTracking(
      _stream.listen(
        onData,
        onError: handleError,
        onDone: handleDone,
        cancelOnError: cancelOnError,
      ),
      _onEvent,
      handleDone: onDone,
      handleError: onError,
    );
    return sub;
  }
}

extension StreamExtension<T> on Stream<T> {
  Stream<T> asCancelable(
    CancellationToken token, {
    required bool throwIfCanceled,
  }) {
    return _CancelableStream(this, token, throwIfCanceled: throwIfCanceled);
  }

  /// Adds a subscription to this stream.\
  /// Immediately cancels the subscription when the token status changes to
  /// `canceled`.
  ///
  /// Additionally, a [TaskCanceledException] error event will be sent to the
  /// subscriber if the [throwIfCanceled] parameter has the value `true`.\
  /// This can be useful if the code waiting for a subscription via a call to
  /// the `asFuture()` method or via the `await for` statement, because this
  /// clearly signals that the subscription was cancelled abnormally (that is,
  /// upon request for cancellation).
  ///
  /// Example:
  ///
  /// ```dart
  /// final stream = response.stream;
  /// await stream.listenWithCancellation(token: token, throwIfCanceled: true,
  ///     (event) {
  ///   // Handles event
  /// }).asFuture<void>();
  /// ```
  StreamSubscription<T> listenWithCancellation(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    required CancellationToken token,
    required bool throwIfCanceled,
  }) {
    final controller = StreamController<T>();
    final iterator = StreamIterator(this);
    var wasErrorSent = false;
    final handler = token.addHandler(() async {
      if (throwIfCanceled && !wasErrorSent && !controller.isClosed) {
        controller.addError(TaskCanceledException(), StackTrace.current);
      }

      await iterator.cancel();
    });
    unawaited(() async {
      try {
        while (await iterator.moveNext()) {
          controller.add(iterator.current);
        }
      } catch (e, s) {
        if (e is TaskCanceledException) {
          wasErrorSent = true;
        }

        controller.addError(e, s);
      } finally {
        token.removerHandler(handler);
        await controller.close();
      }
    }());

    final stream = controller.stream;
    return stream.listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  /// Wraps this [Stream] and returns the wrapper that monitors its own
  /// subscriptions lifecycle and notifies about subscription state changes.
  ///
  /// Parameters:
  ///
  /// [onEvent] A callback function that is triggered whenever a
  /// [SubscriptionEvent] occurs.
  ///
  /// This method allows to track when a subscription starts, pauses, resumes,
  /// or cancels, as well as when a subscription ends or an error occurs.
  Stream<T> withSubscriptionTracking(
    void Function(SubscriptionEvent event) onEvent,
  ) {
    return _StreamWithSubscriptionTracking(this, onEvent);
  }
}
