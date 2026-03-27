import 'dart:math';

class TokenBucket {
  /// Bucket capacity (in tokens).
  final double _capacity;

  /// Clock for measuring time intervals.
  final Stopwatch _clock = Stopwatch();

  /// Elapsed time since last refill (in microseconds).
  int _lastRefill = 0;

  /// Refill rate of the bucket (tokens per second).
  final double _rate;

  /// Current number of tokens in the bucket.
  double _tokens;

  /// Creates an instance of [TokenBucket].\
  /// Parameters:
  ///
  /// - [capacity]: Bucket capacity (in tokens).
  /// - [rate]: Refill rate of the bucket (tokens per second).
  TokenBucket({
    required double capacity,
    required double rate,
  })  : _capacity = capacity,
        _rate = rate,
        _tokens = capacity {
    _clock.start();
    _lastRefill = _clock.elapsedMicroseconds;
  }

  bool allowRequest() {
    final now = _clock.elapsedMicroseconds;
    _tokens += (now - _lastRefill) * _rate / 1e6;
    _tokens = min(_tokens, _capacity);
    _lastRefill = now;
    if (_tokens > 0) {
      _tokens--;
      return true;
    } else {
      return false;
    }
  }
}
