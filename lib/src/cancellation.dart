import '../multitasking.dart';
import 'errors.dart';

class CancellationToken {
  final Map<AnyTask, void Function(AnyTask)> _handlers = {};

  bool _isCancelled = false;

  bool get isCancelled {
    return _isCancelled;
  }

  void addHandler(AnyTask task, void Function(AnyTask) handler) {
    if (_isCancelled) {
      handler(task);
      return;
    }

    _handlers[task] = handler;
  }

  void removeHandler(AnyTask task) {
    _handlers.remove(task);
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw TaskCanceledError();
    }
  }
}

class CancellationTokenSource {
  final CancellationToken token = CancellationToken();

  void cancel() {
    token._isCancelled = true;
    final handlers = Map.of(token._handlers);
    token._handlers.clear();
    for (final entry in handlers.entries) {
      final task = entry.key;
      final handler = entry.value;
      handler(task);
    }
  }
}
