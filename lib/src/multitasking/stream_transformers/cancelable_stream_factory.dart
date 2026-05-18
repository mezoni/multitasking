import 'dart:async';

import '../cancellation.dart';

/// A [CancelableStreamFactory] is a [Stream] factory that delegates stream
/// creation to a function with a `token` parameter, which takes responsibility
/// for creating a stream that will support cancellation of a subscription when
/// cancellation is requested via a [CancellationToken].
class CancelableStreamFactory {
  /// Creates a [Stream] that will support cancellation of a subscription when
  /// cancellation is requested via a `token`.
  ///
  /// Parameters:
  ///
  /// - [generate]:  Delegate function that takes responsibility for creating a
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
}
