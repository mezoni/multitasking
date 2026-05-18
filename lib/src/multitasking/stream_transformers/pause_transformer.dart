import 'dart:async';

import '../../../misc/pause.dart';
import '../cancellation.dart';
import 'cancellation_transformer.dart';

/// A [PauseTransformer] is a transformer that allows to pause/resume
/// a stream subscription using a [PauseToken].
///
/// The transformer works the same as if the `pause()` and `resume()` methods
/// were called directly on the [StreamSubscription] instance instance of the
/// transform stream.
///
/// ⚠️ Warning:\
/// The stream subscription pause notification is propagated in the upstream
/// direction (toward the source).\
/// For this reason, it is strongly recommended to place this transformer at
/// the very end of the transformer chain.\
/// This will ensure that all listeners in the chain are notified.
///
/// For example, if place this transformer before a transformer that handles
/// a timeout, then that transformer will not be notified of the pause and
/// will throw a [TimeoutException] exception.
///
/// The specifics of the [PauseTokenSource] functionality do not provide the
/// ability to track direct calls to the `pause` and `resume` subscription
/// methods and thus do not ensure the use of both the [PauseToken] and direct
/// calls to these methods simultaneously.
class PauseTransformer<T> extends StreamTransformerBase<T, T> {
  final PauseToken _token;

  /// Creates an instance of [PauseTransformer].
  ///
  /// Parameters:
  ///
  /// - [token]: Pause token that is used to be pause and resume the
  /// subscription.
  @Deprecated(
      'This will be removed in the next version. Use CancellationTransformer() instead')
  PauseTransformer(PauseToken token) : _token = token;

  @override
  Stream<T> bind(Stream<T> stream) {
    return CancellationTransformer<T>(
      CancellationTokenSource().token,
      pauseToken: _token,
    ).bind(stream);
  }
}
