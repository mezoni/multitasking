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

class _CancelableStream<T> extends Stream<T> {
  final Stream<T> _stream;

  final bool _throwIfCanceled;

  final CancellationToken _token;

  _CancelableStream(
    Stream<T> stream,
    CancellationToken token, {
    bool throwIfCanceled = true,
  })  : _stream = stream,
        _throwIfCanceled = throwIfCanceled,
        _token = token;

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

class _StreamSubscriptionWrapper<T> implements StreamSubscription<T> {
  final void Function()? _onCanceled;

  final StreamSubscription<T> _subscription;

  _StreamSubscriptionWrapper(StreamSubscription<T> subscription,
      {required void Function() onCanceled})
      : _onCanceled = onCanceled,
        _subscription = subscription;

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _subscription.asFuture(futureValue);
  }

  @override
  Future<void> cancel() {
    try {
      return _subscription.cancel();
    } finally {
      if (_onCanceled != null) {
        _onCanceled!();
      }
    }
  }

  @override
  void onData(void Function(T data)? handleData) {
    _subscription.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _subscription.onDone(handleDone);
  }

  @override
  void onError(Function? handleError) {
    _subscription.onError(handleError);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _subscription.pause(resumeSignal);
  }

  @override
  void resume() {
    _subscription.resume();
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
    return _createSubscription(
      _stream,
      _onEvent,
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  static _StreamSubscriptionWithTracking<T> _createSubscription<T>(
    Stream<T> stream,
    void Function(SubscriptionEvent event) onEvent,
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _StreamSubscriptionWithTracking<T>? subscription;

    void handleDone() {
      final handleDone = subscription!._handleDone;
      try {
        if (handleDone != null) {
          handleDone();
        }
      } finally {
        onEvent(SubscriptionEvent.done);
      }
    }

    void handleError(Object error, StackTrace stackTrace) {
      final handleError = subscription!._handleError;
      try {
        if (handleError != null) {
          if (handleError is void Function(Object, StackTrace)) {
            handleError(error, stackTrace);
          } else if (handleError is void Function(Object)) {
            handleError(error);
          } else {
            throw StateError(
              'Error handler must accept one Object or one Object and a StackTrace as arguments',
            );
          }
        }
      } finally {
        onEvent(SubscriptionEvent.error);
      }
    }

    onEvent(SubscriptionEvent.start);
    subscription = _StreamSubscriptionWithTracking(
      stream.listen(
        onData,
        onError: handleError,
        onDone: handleDone,
        cancelOnError: cancelOnError,
      ),
      onEvent,
      handleDone: onDone,
      handleError: onError,
    );
    return subscription;
  }
}

/// A [StreamExtension] is an extension for [Stream] with various usefu
///  methods.
extension StreamExtension<T> on Stream<T> {
  /// Returns a stream whose subscriptions can be canceled using a cancellation
  /// [token].
  ///
  /// Cancellation is performed by adding the error [TaskCanceledException] to
  /// the outgoing stream.
  Stream<T> asCancelable(
    CancellationToken token, {
    bool throwIfCanceled = true,
  }) {
    return _CancelableStream(this, token, throwIfCanceled: throwIfCanceled);
  }

  /// Adds a stream subscription that can be cancelled using a cancellation
  /// [token].
  ///
  /// Cancellation is performed by adding the error [TaskCanceledException] to
  /// the outgoing stream.
  StreamSubscription<T> listenWithCancellation(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    required CancellationToken token,
    bool throwIfCanceled = true,
  }) {
    if (token.isCanceled) {
      if (throwIfCanceled) {
        return Stream<T>.error(
          TaskCanceledException(),
          StackTrace.current,
        ).listen(
          onData,
          onDone: onDone,
          onError: onError,
          cancelOnError: cancelOnError,
        );
      } else {
        return Stream<T>.empty().listen(
          onData,
          onDone: onDone,
          onError: onError,
          cancelOnError: cancelOnError,
        );
      }
    }

    final output = StreamController<T>(sync: true);
    final input = listen(
      output.add,
      onDone: output.close,
      onError: output.addError,
      cancelOnError: cancelOnError,
    );

    final handler = token.addHandler(() async {
      if (output.isClosed) {
        return;
      }

      if (throwIfCanceled) {
        output.addError(TaskCanceledException(), StackTrace.current);
      }

      await input.cancel();
      await output.close();
    });

    final stream = output.stream;
    return _StreamSubscriptionWrapper(
      stream.listen(
        onData,
        onDone: onDone,
        onError: onError,
        cancelOnError: cancelOnError,
      ),
      onCanceled: () async {
        await input.cancel();
        token.removerHandler(handler);
      },
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
