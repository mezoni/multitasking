import 'dart:async';

import '../../misc/pause.dart';
import '../../multitasking.dart';

/// A [CancelableStreamFactory] is a [Stream] factory which delegates stream
/// creation to a function with a `token` parameter, which takes responsibility
/// for creating a stream that will support cancellation of a subscription when
/// cancellation is requested via a [CancellationToken].
class CancelableStreamFactory {
  /// Creates a [Stream] that will support cancellation of a subscription when
  /// cancellation is requested via a `token`.
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

/// A [CancellationTransformer] is a stream transformer which allows to `cancel`
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

/// A [PauseTransformer] is a transformer which allows to pause/resume
/// a stream subscription using a [PauseToken].
///
/// The transformer works the same as if the `pause()` and `resume()` methods
/// were called directly on the [StreamSubscription] instance instance of the
/// transform stream.
///
/// ⚠️ Warning:\
/// The stream subscription pause notification is propagated in the upstream
/// direction (toward the source).\
/// For this reason, it is strongly recommended to place this transformer at
/// the very end of the transformer chain.\
/// This will ensure that all listeners in the chain are notified.
///
/// For example, if place this transformer before a transformer that handles
/// a timeout, then that transformer will not be notified of the pause and
/// will throw a [TimeoutException] exception.
///
/// The specifics of the [PauseTokenSource] functionality do not provide the
/// ability to track direct calls to the `pause` and `resume` subscription
/// methods and thus do not ensure the use of both the [PauseToken] and direct
/// calls to these methods simultaneously.
class PauseTransformer<T> extends StreamTransformerBase<T, T> {
  // coverage:ignore-start
  final PauseToken _token;

  /// Creates an instance of [PauseTransformer].
  ///
  /// Parameters:
  ///
  /// - [token]: Pause token, which is used to be pause and resume the
  /// subscription.
  @Deprecated(
      'This will be removed in the next version. Use CancellationTransformer() instead')
  PauseTransformer(PauseToken token) : _token = token;

  @override
  Stream<T> bind(Stream<T> stream) {
    return CancellationTransformer<T>(
      CancellationTokenSource().token,
      pauseToken: _token,
    ).bind(stream);
  }
}

/// A [TerminationTransformer] is a stream transformer which allows to define
/// the status handlers `onCancel`, `onDone` and `onError`, and the termination
/// handler `onTerminate`.
///
/// The transformer ensures that at least one of the status handlers is called
/// before the `onTerminate` callback is called.
///
/// The number of calls to the `onError` handler depends on the value of the
/// `cancelOnError` subscription parameter.
class TerminationTransformer<T> extends StreamTransformerBase<T, T> {
  final void Function()? _onCancel;

  final void Function()? _onDone;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  final void Function()? _onTerminate;

  /// Creates an instance of [TerminationTransformer].
  ///
  /// Parameters:
  ///
  /// - [onCancel]: Callback which handles explicit cancellation of listening to
  /// a stream.
  /// - [onDone]: A callback which handles the `onDone` event.
  /// - [onError]: A callback which handles the `onError` event.
  /// - [onTerminate]: A callback that will be called when the stream
  /// terminates.
  TerminationTransformer({
    void Function()? onCancel,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onTerminate,
  })  : _onCancel = onCancel,
        _onError = onError,
        _onDone = onDone,
        _onTerminate = onTerminate;

  @override
  Stream<T> bind(Stream<T> stream) {
    return StreamTransformer<T, T>((stream, cancelOnError) {
      late StreamController<T> controller;
      StreamSubscription<T>? subscription;
      bool isHandled = false;

      controller = StreamController<T>(
        sync: true,
        onListen: () {
          subscription = stream.listen(
            (data) => controller.add(data),
            onError: (Object error, StackTrace stackTrace) {
              if (!isHandled) {
                if (cancelOnError) {
                  isHandled = true;
                  _onError?.call(error, stackTrace);
                  _onTerminate?.call();
                } else {
                  _onError?.call(error, stackTrace);
                }
              }

              controller.addError(error, stackTrace);
            },
            onDone: () {
              if (!isHandled) {
                isHandled = true;
                _onDone?.call();
                _onTerminate?.call();
              }

              unawaited(controller.close());
            },
            cancelOnError: cancelOnError,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () {
          if (!isHandled) {
            isHandled = true;
            _onCancel?.call();
            _onTerminate?.call();
          }

          return subscription?.cancel() ?? Future.value();
        },
      );

      return controller.stream.listen(null);
    }).bind(stream);
  }
}

class _StreamSubscriptionWrapper<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _subscription;

  _StreamSubscriptionWrapper(this._subscription);

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _subscription.asFuture(futureValue);
  }

  @override
  Future<void> cancel() {
    return _subscription.cancel();
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
  // coverage:ignore-end
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
    final stream = _generate(cts.token);
    return _SubscriptionWithCancellationTokenSource(
      stream.listen(
        onData,
        onDone: onDone,
        onError: onError,
        cancelOnError: cancelOnError,
      ),
      cts,
    );
  }
}

class _SubscriptionWithCancellationTokenSource<T>
    extends _StreamSubscriptionWrapper<T> {
  final CancellationTokenSource _cts;

  _SubscriptionWithCancellationTokenSource(super._subscription, this._cts);

  @override
  Future<void> cancel() {
    _cts.cancel();
    return _subscription.cancel();
  }
}

/// A [StreamExtension] is an extension for [Stream] with various useful
///  methods.
extension StreamExtension<T> on Stream<T> {
  /// Returns a stream which allows to `cancel` a subscription using a
  /// `cancellation token` or a specified `timeout`, with support for
  /// `non-blocking` cancellation, and with support for sending a request to
  /// `pause` a stream and `resume` after a pause using a `pause token`.
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
  ///
  /// The cancelable stream is created using the [CancellationTransformer]
  /// transformer.
  Stream<T> asCancelable(
    CancellationToken token, {
    bool blockOnCancel = true,
    PauseToken? pauseToken,
    Duration? timeout,
  }) {
    return CancellationTransformer<T>(
      token,
      blockOnCancel: blockOnCancel,
      pauseToken: pauseToken,
      timeout: timeout,
    ).bind(this);
  }

  /// Returns a stream which allows to pause/resume a stream subscription using
  /// a [PauseToken].
  ///
  /// Parameters:
  ///
  /// - [token]: Pause token, which is used to be pause and resume the
  /// subscription.
  ///
  /// The pausable stream is created using the [PauseTransformer] transformer.
  ///
  /// ⚠️ Warning:\
  /// The stream subscription pause notification is propagated in the upstream
  /// direction (toward the source).\
  /// For this reason, it is strongly recommended to place this transformer at
  /// the very end of the transformer chain.\
  /// This will ensure that all listeners in the chain are notified.
  ///
  /// For example, if place this transformer before a transformer that handles
  /// a timeout, then that transformer will not be notified of the pause and
  /// will throw a [TimeoutException] exception.
  ///
  /// The specifics of the [PauseTokenSource] functionality do not provide the
  /// ability to track direct calls to the `pause` and `resume` subscription
  /// methods and thus do not ensure the use of both the [PauseToken] and direct
  /// calls to these methods simultaneously.
  // coverage:ignore-start
  @Deprecated(
      'This will be removed in the next version. Use asCancelable() instead')
  Stream<T> asPausable(PauseToken token) {
    return PauseTransformer<T>(token).bind(this);
  }
  // coverage:ignore-end

  /// Returns a stream which allows to define the status handlers `onCancel`,
  /// `onDone` and `onError`, and the termination handler `onTerminate`.
  ///
  /// Parameters:
  ///
  /// - [onCancel]: Callback which handles explicit cancellation of listening to
  /// a stream.
  /// - [onDone]: A callback which handles the `onDone` event.
  /// - [onError]: A callback which handles the `onError` event.
  /// - [onTerminate]: A callback that will be called when the stream
  /// terminates.
  ///
  /// The stream handling termination is created using the
  /// [TerminationTransformer] transformer.
  Stream<T> handleTermination({
    void Function()? onCancel,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onTerminate,
  }) {
    return TerminationTransformer<T>(
      onCancel: onCancel,
      onDone: onDone,
      onError: onError,
      onTerminate: onTerminate,
    ).bind(this);
  }
}
