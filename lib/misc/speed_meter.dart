/// The [SpeedMeter] class is intended to measure the date processing or
/// transferring speed.
class SpeedMeter {
  final Stopwatch _clock = Stopwatch();

  int _currentAmount = 0;

  int _previousTime = 0;

  int _totalAmount = 0;

  /// Creates an instance of [SpeedMeter] in the `paused` state.
  SpeedMeter();

  /// Creates an instance of [SpeedMeter] and starts the measurement.
  SpeedMeter.run() {
    _clock.start();
  }

  /// Returns the cumulative time of measurements.\
  ///
  /// The [pause] method pauses the measurement.\
  /// The [resume] method resumes the measurement.\
  /// The [reset] method resets the measurement values.\
  int get elapsedMicroseconds => _clock.elapsedMicroseconds;

  double get speed {
    if (!_clock.isRunning) {
      return 0;
    }

    final now = _clock.elapsedMicroseconds;
    final elapsed = now - _previousTime;
    final speed = elapsed == 0 ? 0.0 : _currentAmount / elapsed * 1e6;
    _currentAmount = 0;
    _previousTime = now;
    return speed;
  }

  /// Returns the total amount of data added.
  int get totalAmount => _totalAmount;

  /// Adds the specified [amount] of data for the measuring.
  void add(int amount) {
    if (!_clock.isRunning) {
      return;
    }

    _currentAmount = _currentAmount + amount;
    _totalAmount = _totalAmount + amount;
  }

  /// Pauses the measurement.
  void pause() {
    if (!_clock.isRunning) {
      return;
    }

    _clock.stop();
  }

  /// Resets the measurement values.
  ///
  /// This method does not pause or resume measurements.
  void reset() {
    _currentAmount = 0;
    _totalAmount = 0;
    _previousTime = 0;
    _clock.reset();
  }

  /// Resumes the measurement.
  void resume() {
    if (_clock.isRunning) {
      return;
    }

    _clock.start();
  }
}
