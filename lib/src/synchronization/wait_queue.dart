import 'dart:async';
import 'dart:collection';

/// A [WaitQueue] is an implementation of a wait queue for asynchronous
/// operations.
class WaitQueue {
  static final Future<bool> _false = Future.value(false);

  final LinkedList<_Node> _list = LinkedList();

  /// Returns `true` if the queue is empty.
  bool get isEmpty => _list.isEmpty;

  /// Returns `true` if the queue is not empty.
  bool get isNotEmpty => _list.isNotEmpty;

  /// Removes the first element from the queue and activates it.
  void dequeue() {
    final node = _list.first;
    final timer = node.timer;
    final completer = node.completer;
    timer?.cancel();
    _list.remove(node);
    completer.complete(true);
  }

  /// Adds an element to the end of the queue.
  Future<bool> enqueue([Duration? timeout]) {
    if (timeout == null) {
      final node = _Node();
      _list.add(node);
      return node.future;
    }

    if (timeout.isNegative) {
      throw ArgumentError.value(timeout, 'timeout', 'Must not be negative');
    }

    if (timeout.inMicroseconds == 0) {
      return _false;
    }

    final node = _Node();
    final completer = node.completer;
    node.timer = Timer(timeout, () {
      _list.remove(node);
      node.timer = null;
      completer.complete(false);
    });

    _list.add(node);
    return completer.future;
  }
}

base class _Node extends LinkedListEntry<_Node> {
  final completer = Completer<bool>();

  Timer? timer;

  Future<bool> get future => completer.future;
}
