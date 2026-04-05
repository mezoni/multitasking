import 'dart:async';

import '../multitasking.dart';
import '../src/multitasking/cancellation.dart';
import '../synchronization/reset_events.dart';

/// The [PauseToken] class is intended for pausing and resuming asynchronous
/// operations.
class PauseToken {
  final ManualResetEvent _event = ManualResetEvent(true);

  bool _isPaused = false;

  final Map<FutureOr<void> Function(), Zone> _onPause = {};

  final Map<FutureOr<void> Function(), Zone> _onResume = {};

  PauseToken._();

  /// Returns `true` if the token is in a `paused` state.
  bool get isPaused => _isPaused;

  /// Execute an [action] that can be paused/resumed while it is being executed.
  ///
  /// Parameters:
  ///
  /// - [onPause]: A callback that will `pause` the execution of the [action].
  /// - [onResume]: A callback that will `resume` the execution of the [action].
  /// - [action]: An [action] that supports `pausing`/`resume` on request.
  ///
  /// Performs the following actions:
  ///
  /// - Adds a pause handler [onPause]
  /// - Adds a resume handler [onResume]
  /// - Executes the [action] function
  /// - Removes a pause handler [onPause]
  /// - Removes a resume handler [onResume]
  ///
  /// The [onPause] handler function should initiate the pause procedure
  /// which pauses the execution of the [action] function.\
  /// The [onResume] handler function should initiate the resume procedure
  /// which resume the execution of the [action] function.
  Future<T> runPausable<T>(
    FutureOr<void> Function() onPause,
    FutureOr<void> Function() onResume,
    FutureOr<T> Function() action,
  ) async {
    final zone = Zone.current;
    _onPause[onPause] = zone;
    _onResume[onResume] = zone;
    try {
      return await action();
    } finally {
      _onPause.remove(onPause);
      _onResume.remove(onResume);
    }
  }

  /// Paused execution of the calling code while the token is in the `paused`
  /// state. If the token is not in the `paused` state, then execution of the
  /// calling code continues immediately.
  ///
  /// Parameters:
  ///
  /// - [token]: A cancellation token. If a [token] value is specified, the
  /// method will throw a `TaskCanceledError` exception if cancellation was
  /// requested.
  Future<void> wait({CancellationToken? token}) async {
    if (token != null) {
      token.throwIfCanceled();
    }

    if (!_isPaused) {
      return;
    }

    if (token == null) {
      return _event.wait();
    }

    final completer = Completer<void>();
    final handler = token.addHandler(completer.tryComplete);
    await Future.any([_event.wait(), completer.future]);
    completer.tryComplete();
    token.removerHandler(handler);
    token.throwIfCanceled();
  }

  void _executeHandlers(Map<FutureOr<void> Function(), Zone> handlers) {
    final entries = handlers.entries.toList();
    handlers.clear();
    for (final entry in entries) {
      final callback = entry.key;
      entry.value.scheduleMicrotask(callback);
    }
  }

  Future<void> _pause() async {
    if (_isPaused) {
      return;
    }

    _isPaused = true;
    _executeHandlers(_onPause);
    await _event.reset();
  }

  Future<void> _resume() async {
    if (!_isPaused) {
      return;
    }

    _isPaused = false;
    _executeHandlers(_onResume);
    await _event.set();
  }
}

/// A [PauseTokenSource] class manages the the pause/resume process for
/// asynchronous operations.\
/// It works in conjunction with the [PauseToken] class, providing a
/// `cooperative` pause/resume mechanism.
class PauseTokenSource {
  final PauseToken token = PauseToken._();

  /// Signal to associated token that the operation executions should be
  /// paused.
  Future<void> pause() {
    return token._pause();
  }

  /// Signal to associated token that the operation executions should be
  /// resumed.
  Future<void> resume() {
    return token._resume();
  }
}

extension<T> on Completer<T> {
  void tryComplete([T? value]) {
    if (!isCompleted) {
      complete(value);
    }
  }
}
