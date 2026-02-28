class TimeUtils {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  static int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;
}
