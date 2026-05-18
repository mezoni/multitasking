import 'dart:async';

/// A [TerminationTransformer] is a stream transformer that allows to define the
/// termination handler `onTerminate` and the status handlers `onCancel`,
/// `onDone` and `onError`.
///
/// The transformer ensures that at least one of the status handlers is called
/// before the `onTerminate` callback is called.
///
/// The number of calls to the `onError` handler depends on the value of the
/// `cancelOnError` subscription parameter.
class TerminationTransformer<T> extends StreamTransformerBase<T, T> {
  final void Function()? _onCancel;

  final void Function()? _onDone;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  final void Function()? _onTerminate;

  /// Creates an instance of [TerminationTransformer].
  ///
  /// Parameters:
  ///
  /// - [onTerminate]: A callback that will be called when the stream
  /// - [onCancel]: Callback that handles explicit cancellation of listening to
  /// a stream.
  /// - [onDone]: A callback that handles the `onDone` event.
  /// - [onError]: A callback that handles the `onError` event.
  /// terminates.
  TerminationTransformer(
    void Function()? onTerminate, {
    void Function()? onCancel,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _onCancel = onCancel,
        _onError = onError,
        _onDone = onDone,
        _onTerminate = onTerminate;

  @override
  Stream<T> bind(Stream<T> stream) {
    return StreamTransformer<T, T>((stream, cancelOnError) {
      late StreamController<T> controller;
      StreamSubscription<T>? subscription;
      bool isHandled = false;

      controller = StreamController<T>(
        sync: true,
        onListen: () {
          subscription = stream.listen(
            (data) => controller.add(data),
            onError: (Object error, StackTrace stackTrace) {
              if (!isHandled) {
                if (cancelOnError) {
                  isHandled = true;
                  _onError?.call(error, stackTrace);
                  _onTerminate?.call();
                } else {
                  _onError?.call(error, stackTrace);
                }
              }

              controller.addError(error, stackTrace);
            },
            onDone: () {
              if (!isHandled) {
                isHandled = true;
                _onDone?.call();
                _onTerminate?.call();
              }

              unawaited(controller.close());
            },
            cancelOnError: cancelOnError,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () {
          if (!isHandled) {
            isHandled = true;
            _onCancel?.call();
            _onTerminate?.call();
          }

          return subscription?.cancel() ?? Future.value();
        },
      );

      return controller.stream.listen(null);
    }).bind(stream);
  }
}
