import 'dart:async';
import 'dart:collection';

class WaitQueue {
  static final Future<bool> _false = Future.value(false);

  final LinkedList<_Node> _list = LinkedList();

  bool get isEmpty => _list.isEmpty;

  bool get isNotEmpty => _list.isNotEmpty;

  void dequeue() {
    final node = _list.first;
    final timer = node.timer;
    final completer = node.completer;
    node.unlink();
    timer?.cancel();
    completer.complete(true);
  }

  Future<bool> enqueue([Duration? timeout]) {
    if (timeout == null) {
      final node = _Node();
      _list.add(node);
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
    final completer = node.completer;
    node.timer = Timer(timeout, () {
      node.unlink();
      node.timer = null;
      completer.complete(false);
    });

    _list.add(node);
    return completer.future;
  }

  Completer<bool> removeFirst() {
    final node = _list.first;
    final completer = node.completer;
    final timer = node.timer;
    timer?.cancel();
    node.unlink();
    return completer;
  }
}

base class _Node extends LinkedListEntry<_Node> {
  final completer = Completer<bool>();

  Timer? timer;

  Future<bool> get future => completer.future;
}
