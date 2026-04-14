/// The [SpeedMeter] class is intended for measure the data processing speed.
class SpeedMeter {
  int _currentAmount = 0;

  int _previousTime = 0;

  int _totalAmount = 0;

  final Stopwatch _watch = Stopwatch();

  /// Creates an instance of [SpeedMeter] in the `paused` state.
  SpeedMeter();

  /// Creates an instance of [SpeedMeter] and starts the measurement.
  SpeedMeter.run() {
    _watch.start();
  }

  /// Returns the cumulative time of measurements.\
  ///
  /// The [pause] method pauses the measurement.\
  /// The [resume] method resumes the measurement.\
  /// The [reset] method resets the measurement values.\
  int get elapsedMicroseconds => _watch.elapsedMicroseconds;

  /// Calculates and returns the current speed.
  double get speed {
    if (!_watch.isRunning) {
      return 0;
    }

    final now = _watch.elapsedMicroseconds;
    final elapsed = now - _previousTime;
    final speed = elapsed == 0 ? 0.0 : _currentAmount / elapsed * 1e6;
    _currentAmount = 0;
    _previousTime = now;
    return speed;
  }

  /// Returns the total amount of data added.
  int get totalAmount => _totalAmount;

  /// Adds the specified [amount] of data for the measuring.
  ///
  /// Parameters:
  ///
  /// - [amount]: Amount of data processed.
  void add(int amount) {
    if (!_watch.isRunning) {
      return;
    }

    _currentAmount = _currentAmount + amount;
    _totalAmount = _totalAmount + amount;
  }

  /// Pauses the measurement.
  void pause() {
    if (!_watch.isRunning) {
      return;
    }

    _watch.stop();
  }

  /// Resets the measurement values.
  ///
  /// This method does not pause or resume measurements.
  void reset() {
    _currentAmount = 0;
    _totalAmount = 0;
    _previousTime = 0;
    _watch.reset();
  }

  /// Resumes the measurement.
  void resume() {
    if (_watch.isRunning) {
      return;
    }

    _watch.start();
  }
}
