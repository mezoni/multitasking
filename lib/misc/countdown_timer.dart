import 'dart:async';

/// A [CountdownTimer] is a [Timer] that has the following features:
///
/// - Start (resume) timer [start]
/// - Stop (pause) timer [stop]
/// - Reset [reset]
/// - Get and change [duration]
/// - Get elapsed time ([elapsedMicroseconds])
/// - Get remaining time ([remainingMicroseconds])
/// - Cancel timer ([cancel])
/// - Check if the timer is active ([isActive])
///
/// When the timer reaches the countdown point, the callback will be called
/// without any protection (unguarded) for performance reasons.
class CountdownTimer implements Timer {
  static final Timer _initialTimer = Timer(const Duration(), () {});

  void Function()? _callback;

  Duration _duration;

  final Stopwatch _stopwatch = Stopwatch();

  Timer _timer = _initialTimer;

  CountdownTimer(Duration duration, void Function() callback)
      : _callback = callback,
        _duration = duration;

  /// Returns the timer duration
  Duration get duration => _duration;

  /// Changes the timer duration.\
  /// If the new duration is greater than the current one, then a new duration
  /// value is set.\
  /// If the new duration is less than the current duration, then a check is
  /// made to see if the new duration value points to a time in the past.\
  /// If the time has already expired, the duration is set to the current time
  /// and the timer is terminated by calling the handler.
  ///
  /// Does not perform any action if the timer is no longer active.
  set duration(Duration duration) {
    if (_callback == null) {
      return;
    }

    if (duration.inMicroseconds == _duration.inMicroseconds) {
      return;
    }

    final elapsedMicroseconds = _stopwatch.elapsedMicroseconds;
    final remaining = duration.inMicroseconds - elapsedMicroseconds;
    if (remaining <= 0) {
      _duration = Duration(microseconds: elapsedMicroseconds);
      _handle();
      return;
    }

    _duration = duration;
    _timer.cancel();
    duration = Duration(microseconds: remaining);
    _timer = Timer(duration, _handle);
  }

  /// Returns the elapsed time in microseconds.
  int get elapsedMicroseconds {
    final elapsedMicroseconds = _stopwatch.elapsedMicroseconds;
    final inMicroseconds = _duration.inMicroseconds;
    if (elapsedMicroseconds <= inMicroseconds) {
      return elapsedMicroseconds;
    }

    return inMicroseconds;
  }

  @override
  bool get isActive => _callback != null;

  /// Returns the remaining time in microseconds.
  int get remainingMicroseconds {
    final elapsedMicroseconds = _stopwatch.elapsedMicroseconds;
    final remainingMicroseconds =
        _duration.inMicroseconds - elapsedMicroseconds;
    if (remainingMicroseconds >= 0) {
      return remainingMicroseconds;
    }

    return 0;
  }

  @override
  int get tick => 0;

  @override
  void cancel() {
    _stopwatch.stop();
    _timer.cancel();
    _callback = null;
  }

  /// Resets the time countdown.
  ///
  /// This method does not stop or start the timer.
  void reset() {
    if (_callback == null) {
      return;
    }

    _stopwatch.reset();
    if (_stopwatch.isRunning) {
      _timer.cancel();
      _timer = Timer(_duration, _handle);
    }
  }

  /// Starts (or resumes) the time countdown.
  ///
  /// If the [CountdownTimer] currently running, then calling [start] does
  /// nothing.
  void start() {
    if (_stopwatch.isRunning || _callback == null) {
      return;
    }

    _stopwatch.start();
    final remaining = _duration.inMicroseconds - _stopwatch.elapsedMicroseconds;
    if (remaining <= 0) {
      _handle();
      return;
    }

    final duration = Duration(microseconds: remaining);
    _timer = Timer(duration, _handle);
  }

  /// Stops (or pauses) the time countdown.
  ///
  /// If the [CountdownTimer] currently stopped, then calling [stop] does
  /// nothing.
  void stop() {
    if (!_stopwatch.isRunning || _callback == null) {
      return;
    }

    _stopwatch.stop();
    final remaining = _duration.inMicroseconds - _stopwatch.elapsedMicroseconds;
    if (remaining <= 0) {
      _handle();
      return;
    }

    _timer.cancel();
  }

  void _handle() {
    _timer.cancel();
    if (_callback == null) {
      return;
    }

    final callback = _callback!;
    _callback = null;
    callback();
  }
}
