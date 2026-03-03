import 'dart:async';
import 'dart:collection';

import '../time_utils.dart';

class WaitQueue {
  static final Future<bool> _false = Future.value(false);

  final LinkedList<_Node> _queue = LinkedList();

  bool dequeue() {
    int? now;
    while (_queue.isNotEmpty) {
      final node = _queue.first;
      node.unlink();
      final completer = node.completer;
      final timer = node.timer;
      if (timer == null) {
        completer.complete(true);
        return true;
      }

      timer.cancel();
      now ??= TimeUtils.elapsedMicroseconds;
      final timeout = node.timeout;
      if (now - node.started >= timeout) {
        completer.complete(false);
      } else {
        completer.complete(true);
        return true;
      }
    }

    return false;
  }

  Future<bool> enqueue([Duration? timeout]) {
    if (timeout == null) {
      final node = _Node();
      _queue.add(node);
      return node.future;
    }

    if (timeout.isNegative) {
      throw ArgumentError.value(
          timeout, 'timeout', 'Timeout must not be negative');
    }

    if (timeout.inMicroseconds == 0) {
      return _false;
    }

    final node = _Node();
    _queue.add(node);
    node.timeout = timeout.inMicroseconds;
    node.timer = Timer(timeout, () {
      node.unlink();
      node.timer = null;
      final completer = node.completer;
      completer.complete(false);
    });

    node.started = TimeUtils.elapsedMicroseconds;
    final completer = node.completer;
    return completer.future;
  }
}

base class _Node extends LinkedListEntry<_Node> {
  final completer = Completer<bool>();

  int started = 0;

  Timer? timer;

  int timeout = 0;

  Future<bool> get future => completer.future;
}
