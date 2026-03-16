/// A [Throughput] allows to measure data transfer speed.\
class Throughput<T extends num> {
  static final int _k = 1e9 ~/ _stopwatch.frequency;

  static final Stopwatch _stopwatch = Stopwatch()..start();

  int _startedAt = 0;

  T _units = 0 as T;

  /// Returns the elapsed time in nanoseconds.
  int get elapsedNanoseconds {
    if (_startedAt == 0) {
      _startedAt = _stopwatch.elapsedTicks;
    }

    return (_stopwatch.elapsedTicks - _startedAt) * _k;
  }

  T get units => _units;

  /// Adds the specified number of units to the total number of units.
  void add(T units) {
    if (_startedAt == 0) {
      _startedAt = _stopwatch.elapsedTicks;
    }

    _units = (_units as num) + (units as num) as T;
  }

  /// Measures the average speed at the moment and returns the speed of
  /// processing units per second.
  double measure() {
    if (_startedAt == 0) {
      _startedAt = _stopwatch.elapsedTicks;
    }

    final time = (_stopwatch.elapsedTicks - _startedAt) * _k;
    if (time != 0) {
      return _units / (time / 1e9);
    }

    return 0;
  }
}
