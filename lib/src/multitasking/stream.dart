import 'dart:async';

import '../../misc/pause.dart';
import '../../multitasking.dart';

/// A [CancellationTransformer] is a transformer which allows to cancel a
/// subscription using a cancellation token or a specified timeout, with support for
/// non-blocking cancellation.
///
/// Everything described below applies exclusively to cancellation using a
/// token.
///
/// Cancellation of the upstream subscription performed in the standard way (by
/// canceling the subscription to the incoming stream).\
/// Cancellation of the downstream subscription performed in a non-standard way
/// (by adding the [CancellationException] error to the outgoing stream).
///
/// Any error that may occur when canceling upstream subscriptions is ignored.
///
/// ⚠️ Warning:\
/// If the resulting (very last downstream) subscription ignores errors
/// (`cancelOnError` parameter is not set to `true`), it will be impossible to
/// cancel it using the [CancellationException] exception.
///
/// A non-blocking cancellation is a cancellation that does not wait for the
/// cancellation of the upstream subscription to complete.
///
/// Non-blocking cancellation can be useful in cases where the incoming stream
/// has a defect in its implementation and does not respond to cancellation for
/// a long time (especially if the incoming stream is implemented using the
/// `async*` generator and without the ability to quickly respond to
/// cancellation).
class CancellationTransformer<T> extends StreamTransformerBase<T, T> {
  static final _voidFuture = Future<void>.value();

  final bool _blockOnCancel;

  final Duration? _timeout;

  final CancellationToken _token;

  /// Creates an instance of [CancellationTransformer].
  ///
  /// Parameters:
  ///
  /// - [token]: A cancellation token used to canceling the subscription.
  /// - [blockOnCancel]: Specifies whether blocking or non-blocking cancellation
  /// should be used when a cancellation request is received using a token or
  /// the [timeout] period elapsed prior to receiving the data event.
  /// - [timeout]: The time limit at which a [TimeoutException] error will be
  /// added to the stream if no data is received within this interval.
  CancellationTransformer(
    CancellationToken token, {
    bool blockOnCancel = true,
    Duration? timeout,
  })  : _blockOnCancel = blockOnCancel,
        _token = token,
        _timeout = timeout;

  @override
  Stream<T> bind(Stream<T> stream) {
    final controller = StreamController<T>(sync: true);
    controller.onListen = () {
      FutureOr<void> Function()? handler;
      var isCanceled = false;
      var isCancellationInitiated = false;
      late final StreamSubscription<T> subscription;
      Timer? timer;

      void setTimeout(Duration timeout) {
        timer?.cancel();
        if (isCancellationInitiated || isCanceled) {
          return;
        }

        timer = Timer(timeout, () {
          if (isCancellationInitiated || isCanceled) {
            return;
          }

          isCancellationInitiated = true;
          subscription.cancel().ignore();
          if (!controller.isClosed) {
            controller.addError(TimeoutException(null), StackTrace.current);
          }
        });
      }

      subscription = stream.listen(
        (event) {
          controller.add(event);
          if (_timeout != null) {
            setTimeout(_timeout!);
          }
        },
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: false,
      );
      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = () {
        isCanceled = true;
        _token.removerHandler(handler);
        timer?.cancel();
        final result = subscription.cancel();
        if (!isCancellationInitiated) {
          return result;
        }

        if (_blockOnCancel) {
          // Prevent unhandled error.
          return result.catchError(_handleError);
        }

        return _voidFuture;
      };

      void cancel() {
        if (isCancellationInitiated || isCanceled) {
          return;
        }

        isCancellationInitiated = true;
        subscription.cancel().ignore();
        if (!controller.isClosed) {
          controller.addError(CancellationException(), StackTrace.current);
        }
      }

      if (_token.isCanceled) {
        cancel();
      } else {
        handler = _token.addHandler(cancel);
      }

      if (_timeout != null) {
        setTimeout(_timeout!);
      }
    };

    return controller.stream;
  }

  static void _handleError(Object _, StackTrace __) {}
}

class _PausableStream<T> extends Stream<T> {
  final Stream<T> _stream;

  final PauseToken _token;

  _PausableStream(Stream<T> stream, PauseToken token)
      : _stream = stream,
        _token = token;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final completer = Completer<void>();
    final controller = StreamController<T>(sync: true);
    controller.onListen = () {
      void complete() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }

      final subscription = _stream.listen(
        controller.add,
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: cancelOnError,
      );

      controller.onCancel = () async {
        await subscription.cancel();
        await controller.close();
        complete();
      };

      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      if (_token.isPaused) {
        subscription.pause();
      }

      unawaited(() async {
        await _token.runPausable(
          subscription.pause,
          subscription.resume,
          () => completer.future,
        );
      }());
    };

    final stream = controller.stream;
    return stream.listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }
}

/// A [StreamExtension] is an extension for [Stream] with various useful
///  methods.
extension StreamExtension<T> on Stream<T> {
  /// Returns a stream which allows to cancel a subscription using a
  /// cancellation token or a specified timeout, with support for non-blocking
  /// cancellation.
  ///
  /// Parameters:
  ///
  /// - [token]: A cancellation token used to canceling the subscription.
  /// - [blockOnCancel]: Specifies whether blocking or non-blocking cancellation
  /// should be used when a cancellation request is received using a token or
  /// the [timeout] period elapsed prior to receiving the data event.
  /// - [timeout]: The time limit at which a [TimeoutException] error will be
  /// added to the stream if no data is received within this interval.
  ///
  /// The cancelable stream is created using the [CancellationTransformer]
  /// transformer.
  Stream<T> asCancelable(
    CancellationToken token, {
    bool blockOnCancel = true,
    Duration? timeout,
  }) {
    return CancellationTransformer<T>(
      token,
      blockOnCancel: blockOnCancel,
      timeout: timeout,
    ).bind(this);
  }

  /// Returns a stream whose subscriptions can be paused and resumed using a
  /// pause [token].
  ///
  /// Parameters:
  ///
  /// - [token]: Pause token, which is used to be pause and resume the
  /// subscription.
  Stream<T> asPausable(PauseToken token) {
    return _PausableStream(this, token);
  }
}

/// A [CancelableStreamFactory] is a [Stream] factory which delegates stream
/// creation to a function with a `token` parameter, which takes responsibility
/// for creating a stream that will support cancellation of a subscription when
/// cancellation is requested via a [CancellationToken].
class CancelableStreamFactory {
  /// Creates a [Stream] that will support cancellation of a subscription when
  /// cancellation is requested via a [token].
  ///
  /// Parameters:
  ///
  /// - [generate]:  Delegate function which takes responsibility for creating a
  /// stream that will support cancellation of a subscription when cancellation
  /// is requested via a [CancellationToken].
  static Stream<T> fromGenerator<T>(
    Stream<T> Function(CancellationToken token) generate,
  ) {
    return _StreamWithCancellationToken(generate);
  }
}

class _StreamWithCancellationToken<T> extends Stream<T> {
  final Stream<T> Function(CancellationToken token) _generate;

  _StreamWithCancellationToken(
    Stream<T> Function(CancellationToken token) generate,
  ) : _generate = generate;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final cts = CancellationTokenSource();
    final controller = StreamController<T>();
    controller.onListen = () {
      final stream = _generate(cts.token);
      final subscription = stream.listen(
        controller.add,
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: cancelOnError,
      );

      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = () {
        cts.cancel();
        return subscription.cancel();
      };
    };

    final stream = controller.stream;
    return stream.listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }
}
