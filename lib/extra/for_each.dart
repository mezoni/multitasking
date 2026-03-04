import 'dart:async';

import '../multitasking.dart';

class ForEach<T> {
  final Stream<T> stream;

  final _completer = Completer<void>();

  void Function()? _handler;

  final FutureOr<bool> Function(T data) _onData;

  late final StreamSubscription<T> _subscription;

  final CancellationToken _token;

  ForEach(this.stream, CancellationToken token,
      final FutureOr<bool> Function(T event) onData,
      {bool? cancelOnError})
      : _onData = onData,
        _token = token {
    _subscription = stream.listen(
      _listen,
      cancelOnError: cancelOnError,
      onDone: _onDone,
      onError: _onError,
    );
    _handler = token.addHandler(() {
      _removerHandler();
      _subscription.cancel().whenComplete(() {
        if (!_completer.isCompleted) {
          _onError(TaskCanceledError(), StackTrace.current);
        }
      });
    });
  }

  Future<void> get wait => _completer.future;

  void _listen(T data) async {
    if (!await _onData(data)) {
      _removerHandler();
      await _subscription.cancel();
      _onDone();
    }
  }

  void _onDone() {
    _removerHandler();
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    _removerHandler();
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }

  void _removerHandler() {
    if (_handler != null) {
      _token.removerHandler(_handler);
    }

    _handler = null;
  }
}
