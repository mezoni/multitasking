import 'dart:async';

import '../../multitasking.dart';

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
    Future<void> Function()? handler;
    final controller = StreamController<T>(onCancel: () {
      _token.removerHandler(handler);
    });

    final input = _stream.listen(
      controller.add,
      onDone: controller.close,
      onError: controller.addError,
    );

    final stream = controller.stream;
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    Future<void> cancel() async {
      if (controller.isClosed) {
        return;
      }

      if (_throwIfCanceled) {
        controller.addError(TaskCanceledException(), StackTrace.current);
      }

      await input.cancel();
      await controller.close();
    }

    if (_token.isCanceled) {
      unawaited(cancel());
    } else {
      _token.addHandler(cancel);
    }

    return subscription;
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
    Future<void> beforeCancel() async {
      _onEvent(SubscriptionEvent.cancel);
    }

    void beforeDone() {
      _onEvent(SubscriptionEvent.done);
    }

    void beforeError(Object error, StackTrace stackTrace) {
      _onEvent(SubscriptionEvent.error);
    }

    void beforePause([Future<void>? resumeSignal]) {
      _onEvent(SubscriptionEvent.pause);
    }

    void beforeResume() {
      _onEvent(SubscriptionEvent.resume);
    }

    _onEvent(SubscriptionEvent.start);
    return _TraceableStreamSubscription(
      _stream,
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
      beforeCancel: beforeCancel,
      beforeDone: beforeDone,
      beforeError: beforeError,
      beforePause: beforePause,
      beforeResume: beforeResume,
    );
  }
}

class _TraceableStreamSubscription<T> implements StreamSubscription<T> {
  final Future<void> Function()? _afterCancel;

  final void Function(T event)? _afterData;

  final void Function()? _afterDone;

  final void Function(Object error, StackTrace stackTrace)? _afterError;

  final void Function([Future<void>? resumeSignal])? _afterPause;

  final void Function()? _afterResume;

  final Future<void> Function()? _beforeCancel;

  final void Function()? _beforeDone;

  final void Function([Future<void>? resumeSignal])? _beforePause;

  final void Function()? _beforeResume;

  final void Function(Object error, StackTrace stackTrace)? _beforeError;

  final void Function(T event)? _beforeData;

  void Function(T event)? _onData;

  void Function()? _onDone;

  void Function(Object error, StackTrace stackTrace)? _onError;

  late final StreamSubscription<T> _source;

  _TraceableStreamSubscription(
    Stream<T> stream,
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    Future<void> Function()? afterCancel,
    void Function(T event)? afterData,
    void Function()? afterDone,
    void Function(Object error, StackTrace stackTrace)? afterError,
    void Function([Future<void>? resumeSignal])? afterPause,
    void Function()? afterResume,
    Future<void> Function()? beforeCancel,
    void Function(T event)? beforeData,
    void Function()? beforeDone,
    void Function(Object error, StackTrace stackTrace)? beforeError,
    void Function([Future<void>? resumeSignal])? beforePause,
    void Function()? beforeResume,
  })  : _afterCancel = afterCancel,
        _afterData = afterData,
        _afterDone = afterDone,
        _afterError = afterError,
        _afterPause = afterPause,
        _afterResume = afterResume,
        _beforeCancel = beforeCancel,
        _beforeData = beforeData,
        _beforeDone = beforeDone,
        _beforeError = beforeError,
        _beforePause = beforePause,
        _beforeResume = beforeResume,
        _onData = onData,
        _onDone = onDone,
        _onError = onError == null ? null : _convertToErrorHandler(onError) {
    _source = stream.listen(
      _handleData,
      onDone: _handleDone,
      onError: _handleError,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool get isPaused => _source.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _source.asFuture(futureValue);
  }

  @override
  Future<void> cancel() async {
    try {
      if (_beforeCancel != null) {
        await _beforeCancel!();
      }
    } finally {
      try {
        return await _source.cancel();
      } finally {
        if (_afterCancel != null) {
          await _afterCancel!();
        }
      }
    }
  }

  @override
  void onData(void Function(T data)? handleData) {
    _onData = handleData;
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void onError(Function? handleError) {
    _onError = handleError == null ? null : _convertToErrorHandler(handleError);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    try {
      if (_beforePause != null) {
        _beforePause!(resumeSignal);
      }
    } finally {
      try {
        _source.pause(resumeSignal);
      } finally {
        if (_afterPause != null) {
          _afterPause!(resumeSignal);
        }
      }
    }
  }

  @override
  void resume() {
    try {
      if (_beforeResume != null) {
        _beforeResume!();
      }
    } finally {
      try {
        _source.resume();
      } finally {
        if (_afterResume != null) {
          _afterResume!();
        }
      }
    }
  }

  void _handleData(T event) {
    try {
      if (_beforeData != null) {
        _beforeData!(event);
      }
    } finally {
      try {
        if (_onData != null) {
          _onData!(event);
        }
      } finally {
        if (_afterData != null) {
          _afterData!(event);
        }
      }
    }
  }

  void _handleDone() {
    try {
      if (_beforeDone != null) {
        _beforeDone!();
      }
    } finally {
      try {
        if (_onDone != null) {
          _onDone!();
        }
      } finally {
        if (_afterDone != null) {
          _afterDone!();
        }
      }
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    try {
      if (_beforeError != null) {
        _beforeError!(error, stackTrace);
      }
    } finally {
      try {
        if (_onError != null) {
          _onError!(error, stackTrace);
        }
      } finally {
        if (_afterError != null) {
          _afterError!(error, stackTrace);
        }
      }
    }
  }

  static void Function(Object error, StackTrace stackTrace)
      _convertToErrorHandler(Function handleError) {
    if (handleError is void Function(Object, StackTrace)) {
      return handleError;
    } else if (handleError is void Function(Object)) {
      return (Object error, StackTrace _) {
        return handleError(error);
      };
    } else {
      throw ArgumentError(
          "The 'handleError' callback function must accept either one parameter (Object error) or two parameters (Object error, StackTrace stackTrace)");
    }
  }
}

/// A [StreamExtension] is an extension for [Stream] with various useful
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
