import 'dart:async';

import '../../misc/pause.dart';
import '../../multitasking.dart';

export 'stream_transformers/cancelable_stream_factory.dart';
export 'stream_transformers/cancellation_transformer.dart';
export 'stream_transformers/completion_transformer.dart';
export 'stream_transformers/pause_transformer.dart';
export 'stream_transformers/termination_transformer.dart';

/// A [StreamExtension] is an extension for [Stream] with various useful
///  methods.
extension StreamExtension<T> on Stream<T> {
  /// Returns a stream that allows to `cancel` a subscription using a
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

  /// Returns a stream that allows to pause/resume a stream subscription using
  /// a [PauseToken].
  ///
  /// Parameters:
  ///
  /// - [token]: Pause token, that is used to be pause and resume the
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
  @Deprecated(
      'This will be removed in the next version. Use asCancelable() instead')
  Stream<T> asPausable(PauseToken token) {
    return PauseTransformer<T>(token).bind(this);
  }

  /// Returns a stream that allows to define the termination handler
  /// `onTerminate` and the status handlers `onCancel`, `onDone` and `onError`.
  ///
  /// Parameters:
  ///
  /// - [onCancel]: Callback that handles explicit cancellation of listening to
  /// a stream.
  /// - [onDone]: A callback that handles the `onDone` event.
  /// - [onError]: A callback that handles the `onError` event.
  /// - [onTerminate]: A callback that will be called when the stream
  /// terminates.
  ///
  /// The stream handling termination is created using the
  /// [TerminationTransformer] transformer.
  Stream<T> handleTermination(
    void Function()? onTerminate, {
    void Function()? onCancel,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return TerminationTransformer<T>(
      onTerminate,
      onCancel: onCancel,
      onDone: onDone,
      onError: onError,
    ).bind(this);
  }

  /// Returns a stream whose completion status can be retrieved using
  /// [StreamCompletion].
  ///
  /// Parameters:
  ///
  /// - [completion]: The [StreamCompletion] instance to get a stream completion
  ///  status.
  Stream<T> withCompletion(StreamCompletion completion) {
    return handleTermination(
      completion.terminate,
      onCancel: completion.onCancel,
      onDone: completion.onDone,
      onError: completion.onError,
    );
  }
}
