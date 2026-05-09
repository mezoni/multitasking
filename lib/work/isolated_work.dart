import 'dart:async';
import 'dart:isolate';

import '../src/multitasking/cancellation.dart';
import '../src/multitasking/errors.dart';
import '../src/multitasking/task.dart';
import 'work.dart';

/// A [IsolatedWork] is an operation for executing a computation inside the
/// [Isolate] container with the possibility of externally controlled
/// termination.
class IsolatedWork<T> implements Work<T> {
  final FutureOr<T> Function() _computation;

  Isolate? _isolate;

  bool _isTerminationRequested = false;

  bool _isStarted = false;

  final CancellationToken? _token;

  /// Creates an instance of [IsolatedWork].
  ///
  /// Parameters:
  ///
  /// - [computation]: A callback that represents a computation.
  /// - [token]: Cancellation token used for canceling the execution of
  /// computation.
  ///
  /// If the [token] parameter is specified, it can be retrieved in the
  /// computation] body by calling [Task.token].\
  /// Token-based cancellation is a very flexible cancellation method,
  /// implemented solely based on the cancellation request processing logic.
  IsolatedWork(
    FutureOr<T> Function() computation, {
    CancellationToken? token,
  })  : _computation = computation,
        _token = token;

  /// Executes the computation and returns the computation result (or throws the
  /// exception), or throws the [CancellationException] exception if the [terminate]
  /// method was called before the computation was completed.
  @override
  Future<T> run() async {
    if (_isStarted) {
      throw StateError('The computation can be run only once');
    }

    _isStarted = true;
    if (_isTerminationRequested) {
      throw CancellationException();
    }

    if (_token != null) {
      _token!.throwIfCanceled();
    }

    final completer = Completer<void>();
    var hasResult = false;
    var isCanceled = false;
    T? result;
    Object? error;
    StackTrace? stackTrace;
    final port = RawReceivePort();
    final sendPort = port.sendPort;
    SendPort? remotePort;

    void sendCancellationRequest() {
      remotePort?.send(null);
    }

    void handle(Object? message) {
      if (message is SendPort) {
        remotePort = message;
        return;
      }

      port.close();
      if (message == null) {
        isCanceled = _isTerminationRequested;
      } else if (message is List) {
        error = message[0];
        final stackTraceString = message[1] as String?;
        if (stackTraceString != null && stackTraceString.isNotEmpty) {
          stackTrace = StackTrace.fromString(stackTraceString);
        }
      } else if (message is (String, Object?)) {
        final (event, value) = message;
        switch (event) {
          case 'result':
            hasResult = true;
            result = value as T;
            break;
          case 'cancellation':
            isCanceled = true;
            break;
        }
      }

      _token?.removerHandler(sendCancellationRequest);
      completer.complete();
    }

    port.handler = handle;
    _token?.addHandler(sendCancellationRequest);
    final isolate =
        await Isolate.spawn<(SendPort, FutureOr<T> Function() function)>(
      _compute,
      (sendPort, _computation),
      onError: sendPort,
      onExit: sendPort,
      paused: true,
    );

    _isolate = isolate;
    isolate.resume(isolate.pauseCapability!);
    await completer.future;
    if (error != null) {
      Error.throwWithStackTrace(error!, stackTrace ?? StackTrace.empty);
    } else if (hasResult) {
      return result as T;
    } else if (isCanceled) {
      throw CancellationException();
    } else {
      throw StateError('Computation ended without result');
    }
  }

  /// Requests to terminate the execution of a computation.
  ///
  /// Parameters:
  /// - [force]: Determines whether the execution of the computation will be
  /// terminate immediately or when control is yielded back to the event loop.
  @override
  void terminate({bool force = false}) {
    _isTerminationRequested = true;
    _isolate?.kill(
        priority: force ? Isolate.immediate : Isolate.beforeNextEvent);
  }

  /// Creates an instance of [ZonedWork].
  ///
  /// Parameters:
  ///
  /// - [argument]: Argument to pass to the [computation] function.
  /// - [computation]: A function that represents a computation.
  /// - [token]: Cancellation token used for canceling the execution of
  /// computation.
  ///
  /// If the [token] parameter is specified, it can be retrieved in the
  /// computation] body by calling [Task.token].\
  /// Token-based cancellation is a very flexible cancellation method,
  /// implemented solely based on the cancellation request processing logic.
  static IsolatedWork<R> withArgument<T, R>(
    T argument,
    FutureOr<R> Function(T arg) computation, {
    CancellationToken? token,
  }) {
    return IsolatedWork(() => computation(argument), token: token);
  }

  static void _compute<T>(
    (SendPort sendPort, FutureOr<T> Function() computation) arg,
  ) {
    final cts = CancellationTokenSource();
    final (sendPort, computation) = arg;
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    port.listen((_) {
      cts.cancel();
    });

    Task.run(token: cts.token, () {
      unawaited(() async {
        try {
          await Future<void>.delayed(Duration.zero);
          final result = computation();
          if (result is Future) {
            final value = await result;
            sendPort.send(('result', value));
          } else {
            sendPort.send(('result', result));
          }
        } on CancellationException catch (e, s) {
          sendPort.send(('cancellation', s));
        } finally {
          port.close();
        }
      }());
    }).ignore();
  }
}
