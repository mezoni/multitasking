import 'dart:async';

import 'cancellation.dart';
import 'errors.dart';

extension StreamExtension<T> on Stream<T> {
  /// Adds a subscription to this stream.\
  /// Immediately cancels the subscription when the token state changes to
  /// `canceled`.
  ///
  /// Additionally, a [TaskCanceledException] error event will be sent to the
  /// subscriber if the [throwIfCancelled] parameter has the value `true`.\
  /// This can be useful if the code waiting for a subscription via a call to
  /// the `asFuture()` method.
  ///
  /// Example:
  ///
  /// ```dart
  /// final stream = response.stream;
  /// await stream.listenWithCancellation(token: token, throwIfCancelled: true,
  ///     (event) {
  ///   // Handles event
  /// }).asFuture<void>();
  /// ```
  StreamSubscription<T> listenWithCancellation(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    required bool throwIfCancelled,
    required CancellationToken token,
  }) {
    final controller = StreamController<T>();
    final iterator = StreamIterator(this);
    var wasErrorSent = false;
    final handler = token.addHandler(() async {
      if (throwIfCancelled && !wasErrorSent && !controller.isClosed) {
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
