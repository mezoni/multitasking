import 'dart:async';

import '../../misc/pause.dart';
import '../../multitasking.dart';

/// A [CancellationTransformer] is a transformer which allows to cancel a
/// subscription using a cancellation token with support for non-blocking
/// cancellation.
///
/// Cancellation of the upstream subscription performed in the standard way (by
/// canceling the subscription to the incoming stream).\
/// Cancellation of the downstream subscription performed in a non-standard way
/// (by adding the [CancellationException] error to the outgoing stream).
///
/// ⚠️ Warning:\
/// If the resulting (very last downstream) subscription ignores errors
/// (`cancelOnError` parameter is not set to `true`), it will be impossible to
/// cancel it using the [CancellationException] exception.
///
/// A non-blocking cancellation is a cancellation that does not wait for the
/// cancellation of the previous subscription to complete.\
/// Any error that may occur when canceling previous subscriptions is ignored.
class CancellationTransformer<T> extends StreamTransformerBase<T, T> {
  static final _voidFuture = Future<void>.value();

  final bool _blockOnCancel;

  final CancellationToken _token;

  /// Creates an instance of [CancellationTransformer].
  ///
  /// Parameters:
  ///
  /// - [token]: A cancellation token used to canceling the subscription.
  /// - [blockOnCancel]: Indicates that a non-blocking cancellation should be
  /// performed.
  CancellationTransformer(
    CancellationToken token, {
    bool blockOnCancel = true,
  })  : _blockOnCancel = blockOnCancel,
        _token = token;

  @override
  Stream<T> bind(Stream<T> stream) {
    final controller = StreamController<T>(sync: true);
    controller.onListen = () {
      FutureOr<void> Function()? handler;
      var isCancellationRequested = false;
      final subscription = stream.listen(
        controller.add,
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: false,
      );
      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = () {
        _token.removerHandler(handler);
        var result = subscription.cancel();
        if (isCancellationRequested || !_blockOnCancel) {
          // Prevent unhandled error.
          result = result.catchError((e) {});
        }

        if (_blockOnCancel) {
          return result;
        }

        return _voidFuture;
      };

      void cancel() {
        isCancellationRequested = true;
        // Ignore the error at this point.
        unawaited(subscription.cancel().catchError((e) {}));
        if (!controller.isClosed) {
          controller.addError(CancellationException(), StackTrace.current);
        }
      }

      if (_token.isCanceled) {
        cancel();
      } else {
        handler = _token.addHandler(cancel);
      }
    };

    return controller.stream;
  }
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
  /// Returns a stream which allows to cancel a
  /// subscription using a cancellation token with support for non-blocking
  /// cancellation.
  ///
  /// Parameters:
  ///
  /// - [token]: A cancellation token used to canceling the subscription.
  /// - [blockOnCancel]: Indicates that a non-blocking cancellation should be
  /// performed.
  ///
  /// The cancelable stream is created using the [CancellationTransformer]
  /// transformer.
  Stream<T> asCancelable(
    CancellationToken token, {
    bool blockOnCancel = true,
  }) {
    return CancellationTransformer<T>(
      token,
      blockOnCancel: blockOnCancel,
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
