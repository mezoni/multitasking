import 'dart:async';

import 'cancellation.dart';
import 'errors.dart';

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
}
