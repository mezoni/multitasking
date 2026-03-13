import 'dart:async';

import '../src/multitasking/cancellation.dart';

class CancellableStreamIterator<T> implements StreamIterator<T> {
  void Function()? _handler;

  final StreamIterator<T> _iterator;

  final CancellationToken _token;

  CancellableStreamIterator(Stream<T> stream, CancellationToken token)
      : _iterator = StreamIterator(stream),
        _token = token {
    _handler = token.addHandler(() {
      unawaited(_iterator.cancel());
    });
  }

  @override
  T get current => _iterator.current;

  @override
  Future<Object?> cancel() {
    _token.removerHandler(_handler);
    return _iterator.cancel();
  }

  @override
  Future<bool> moveNext() {
    return _iterator.moveNext();
  }
}
