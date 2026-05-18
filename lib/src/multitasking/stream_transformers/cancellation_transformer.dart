import 'dart:async';

import '../../../misc/pause.dart';
import '../cancellation.dart';
import '../errors.dart';

/// A [CancellationTransformer] is a stream transformer that allows to `cancel`
/// a subscription using a `cancellation token` or a specified `timeout`, with
/// support for `non-blocking` cancellation, and with support for sending a
/// request to `pause` a stream and `resume` after a pause using a
/// `pause token`.
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

  final PauseToken? _pauseToken;

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
  /// - [pauseToken]: Token to request stream pause and resume after pause.
  /// - [timeout]: The time limit at which a [TimeoutException] error will be
  /// added to the stream if no data is received within this interval.
  CancellationTransformer(
    CancellationToken token, {
    bool blockOnCancel = true,
    PauseToken? pauseToken,
    Duration? timeout,
  })  : _blockOnCancel = blockOnCancel,
        _pauseToken = pauseToken,
        _token = token,
        _timeout = timeout {
    if (timeout != null) {
      if (timeout.inMicroseconds <= 0) {
        throw ArgumentError.value(timeout, 'timeout', 'Must be greater than 0');
      }
    }
  }

  @override
  Stream<T> bind(Stream<T> stream) {
    final controller = StreamController<T>(sync: true);

    controller.onListen = () {
      Completer<void>? pauseCompleter;
      final pauseToken = _pauseToken;
      FutureOr<void> Function()? handler;
      var isCancellationInitiated = false;
      late final StreamSubscription<T> subscription;
      Timer? timer;

      void setTimeout(Duration timeout) {
        timer?.cancel();
        // coverage:ignore-start
        if (isCancellationInitiated) {
          return;
        }
        // coverage:ignore-end

        timer = Timer(timeout, () {
          if (isCancellationInitiated || subscription.isPaused) {
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
          timer?.cancel();
          controller.add(event);
          if (_timeout != null) {
            setTimeout(_timeout!);
          }
        },
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: false,
      );

      void pause() {
        timer?.cancel();
        subscription.pause();
      }

      void resume() {
        subscription.resume();
        if (!controller.isPaused) {
          if (_timeout != null) {
            setTimeout(_timeout!);
          }
        }
      }

      if (pauseToken != null) {
        if (pauseToken.isPaused) {
          pause();
        }

        pauseCompleter = Completer();
        unawaited(pauseToken.runPausable(
            pause, resume, () => pauseCompleter!.future));
      }

      controller.onPause = pause;
      controller.onResume = resume;
      controller.onCancel = () {
        _token.removerHandler(handler);
        timer?.cancel();
        pauseCompleter?.complete();
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
        // coverage:ignore-start
        if (isCancellationInitiated) {
          return;
        }
        // coverage:ignore-end

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
        if (_timeout != null) {
          setTimeout(_timeout!);
        }
      }
    };

    return controller.stream;
  }

  static void _handleError(Object _, StackTrace __) {}
}
